## Event-driven skill keys (B's unhooked keys, batch 1; game/content/docs/unhooked_skill_keys.md). Owner: ENV A.
## Server only. Listens to the holder's kills and hits (EventBus npc_killed / damage_applied) and to the deployable
## hooks (DeployablePrefab: doctor bag, ammo bag); timed effects go through CrewBuffs (replicated to clients).
##   weapon.kill_damage_buff [LIST] (PD2 Overkill, Momentum): a kill with a `trigger_class` weapon gives
##     weapon.damage_mult x damage_mult for `duration` s to that class (all_weapons: every class); a kill refreshes it.
##   defense.bullseye {armor, cooldown} (PD2 Bullseye, Clean Shot): a headshot that hurts an enemy restores `armor`
##     armor points, at most once per `cooldown` s.
##   defense.self_revive_charges [ADD] (PD2 Messiah, Comeback): a kill while DOWNED revives the killer; that many
##     uses per heist. defense.self_revive_refill_on_doctor_bag [FLAG] (Aced): a doctor bag use refills them.
##   deploy.ammo_bag_bulletstorm {base_duration, max_duration} (PD2 Bulletstorm, Lead Rain): a crew member who takes
##     ammo from the holder's ammo bag fires without using ammo for base_duration + max_duration x (the share of a
##     full loadout taken) s, at most max_duration.
##   defense.berserk {threshold, max_damage_mult, ranged_max_damage_mult} (PD2 Berserker, Red Mist): berserk_mult()
##     below `threshold` health, linear up to the max at zero health (CrewMelee: melee; CrewWeapons: ranged).
## Batch 2 (crits and dodge):
##   crit_chance(): weapon.crit_chance_add [ADD] + weapon.crit_per_concealment {per_step, points_per_step, threshold_dr,
##     max} (PD2 Low Blow, Cheap Shot: per_step per points_per_step detection-risk points under threshold_dr, at most
##     max); roll_crit() on GameRng "crit" (CombatSystem bullets, CrewMelee) multiplies by CombatTweak.crit_damage_mult.
##   weapon.unseen_strike {idle_s, crit_add, duration} (PD2 Unseen Strike, Ambusher): idle_s without damage taken
##     gives +crit_add crit for as long as it lasts, and `duration` s after the next hit (CrewBuffs "unseen_strike").
##   dodge_add(): defense.dodge_per_concealment (PD2 Sneaky Bastard, Slippery; same shape as Low Blow) +
##     defense.sprint_dodge_add while sprinting (Duck and Cover, Light Step Aced) (CrewHealth.dodge_chance).
##   defense.armor_break_speed_buff {move_mult, duration, team} (PD2 Second Wind, Bolt): armor breaking (CrewHealth)
##     gives move x move_mult for `duration` s, to the whole crew with `team` (CrewBuffs "second_wind").
##   defense.armor_broken_stagger {persist_s} (Cornered ◇): while the holder's armor is broken (and persist_s after
##     it returns) its hits stun a non-special enemy for CombatTweak.armor_broken_stagger_s.
## Batch 3 (revives and medic):
##   revived(): ability.revive_target_buff {damage_taken_mult, duration} (the reviver's; Numbing Agent) and
##     defense.post_revive_buff [LIST] {duration, reload_mult, swap_mult, move_mult, damage_taken_mult} (the revived
##     one's; Back on Your Feet, Second Lease: entries multiply, the longest duration) as CrewBuffs on the revived;
##     ability.revive_target_health_mult (Triage Aced) scales the revive health in CrewHealth.revive.
##   reviving_mult(): defense.reviving_damage_taken_mult {mult, linger_s} (Triage): while holding a revive, and
##     linger_s after, incoming damage x mult (CrewHealth.take_hit).
##   deploy.fak_auto_revive {radius, cooldown} (Field Kit Aced): a crew member DOWNED within radius m of the holder's
##     placed first-aid kit is revived by it (the kit is used); per kit at most once per cooldown s.
##   deploy.medical_user_buff {damage_taken_mult, duration} (Bedside Manner): whoever uses the holder's doctor bag or
##     first-aid kit takes damage x damage_taken_mult for duration s.
##   seen_by_enemy(): defense.bleedout_pause_unseen (Playing Possum): the bleedout pauses while no enemy has line of
##     sight to the downed holder (CrewHealth).
class_name SkillTriggers
extends Node

const SERVICE: StringName = &"skill_triggers"
const NODE_NAME: String = "SkillTriggers"
const BUFF_OVERKILL: StringName = &"overkill"
const BUFF_BULLETSTORM: StringName = &"bulletstorm"
const BUFF_UNSEEN: StringName = &"unseen_strike"
const BUFF_SECOND_WIND: StringName = &"second_wind"
const BUFF_REVIVE_TARGET: StringName = &"revive_target"
const BUFF_POST_REVIVE: StringName = &"post_revive"
const BUFF_MEDICAL: StringName = &"medical_user"
## An enemy farther than this cannot see a downed member (Playing Possum line of sight) ◇.
const POSSUM_SIGHT_M: float = 60.0

## slot -> self-revive charges used this heist (Messiah)
var revives_used: Dictionary[int, int] = {}
## slot -> seconds until Bullseye may restore armor again
var _bullseye_cd: Dictionary[int, float] = {}
## slot -> seconds the holder's hits still stagger after its armor came back (Cornered Aced)
var _stagger_left: Dictionary[int, float] = {}
## slot -> seconds Triage's damage cut lingers after the revive hold
var _reviving_left: Dictionary[int, float] = {}
## first-aid kit instance id -> seconds until it may auto-revive again (Field Kit)
var _fak_cd: Dictionary[int, float] = {}
var _runtime: HeistRuntime = null


## The runtime's SkillTriggers, created on first use (null without a runtime).
static func of(rt: HeistRuntime) -> SkillTriggers:
	if rt == null:
		return null
	var t: SkillTriggers = rt.service(SERVICE) as SkillTriggers
	if t == null:
		t = SkillTriggers.new()
		t.name = NODE_NAME
		t._runtime = rt
		rt.register_service(SERVICE, t)
	return t


func _ready() -> void:
	EventBus.npc_killed.connect(_on_npc_killed)
	EventBus.damage_applied.connect(_on_damage_applied)


func _physics_process(delta: float) -> void:
	for slot: int in _bullseye_cd:
		_bullseye_cd[slot] = maxf(_bullseye_cd[slot] - delta, 0.0)
	if not Net.is_authority() or _runtime == null:
		return
	for crew: CrewController in _runtime.crew_members():
		_tick_unseen_strike(crew)
		_tick_stagger_window(crew, delta)
		_tick_reviving(crew, delta)
	_tick_fak_auto_revive(delta)


## Triage: the linger restarts every tick the holder is holding a revive.
func _tick_reviving(crew: CrewController, delta: float) -> void:
	var p: Dictionary = Modifiers.params(crew.slot, &"defense.reviving_damage_taken_mult")
	if p.is_empty():
		_reviving_left.erase(crew.slot)
		return
	var s: Dictionary = _runtime.interaction.session(crew.slot) if _runtime.interaction != null else {}
	var comp: InteractableComponent = s.get("comp") as InteractableComponent
	if comp != null and is_instance_valid(comp) and comp.kind == &"revive":
		_reviving_left[crew.slot] = float(p.get("linger_s", 0.0)) + 0.001
	else:
		_reviving_left[crew.slot] = maxf(_reviving_left.get(crew.slot, 0.0) - delta, 0.0)


## Triage: incoming damage multiplier for `crew` now.
func reviving_damage_mult(crew: CrewController) -> float:
	if _reviving_left.get(crew.slot, 0.0) <= 0.0:
		return 1.0
	return float(Modifiers.params(crew.slot, &"defense.reviving_damage_taken_mult").get("mult", 1.0))


## Field Kit: each placed first-aid kit whose owner has the key revives a downed crew member in its radius.
func _tick_fak_auto_revive(delta: float) -> void:
	for k: int in _fak_cd.keys():
		_fak_cd[k] = maxf(_fak_cd[k] - delta, 0.0)
	for n: Node in get_tree().get_nodes_in_group(G.DEPLOYABLE):
		var kit: DeployablePrefab = n as DeployablePrefab
		if kit == null or kit.kind != &"fak" or kit.uses_left <= 0 or HeistRuntime.of(kit) != _runtime \
				or _fak_cd.get(kit.get_instance_id(), 0.0) > 0.0:
			continue
		var p: Dictionary = Modifiers.params(kit.owner_slot, &"deploy.fak_auto_revive")
		var radius: float = float(p.get("radius", 0.0))
		if radius <= 0.0:
			continue
		for crew: CrewController in _runtime.crew_members():
			if crew.crew_state == Enums.CrewState.DOWNED and crew.health != null \
					and crew.global_position.distance_to(kit.global_position) <= radius:
				crew.health.revive(kit.owner_slot)
				_fak_cd[kit.get_instance_id()] = float(p.get("cooldown", 0.0))
				kit.consume_use()
				break


## Unseen Strike: refreshed every tick while the holder has gone idle_s without damage.
func _tick_unseen_strike(crew: CrewController) -> void:
	var p: Dictionary = Modifiers.params(crew.slot, &"weapon.unseen_strike")
	if p.is_empty() or crew.health == null or crew.health.since_damage_s < float(p.get("idle_s", 0.0)):
		return
	CrewBuffs.of(_runtime).grant(crew.slot, BUFF_UNSEEN, {&"weapon.crit_chance_add": float(p.get("crit_add", 0.0))},
		float(p.get("duration", 0.0)))


## Cornered: the stagger window is open while the armor is broken and persist_s after it returns.
func _tick_stagger_window(crew: CrewController, delta: float) -> void:
	var p: Dictionary = Modifiers.params(crew.slot, &"defense.armor_broken_stagger")
	if p.is_empty() or crew.health == null:
		_stagger_left.erase(crew.slot)
		return
	if crew.health.armor <= 0.0:
		_stagger_left[crew.slot] = float(p.get("persist_s", 0.0)) + 0.001
	else:
		_stagger_left[crew.slot] = maxf(_stagger_left.get(crew.slot, 0.0) - delta, 0.0)


## Cornered: `crew`'s hits stagger now.
func staggers(crew: CrewController) -> bool:
	return crew != null and _stagger_left.get(crew.slot, 0.0) > 0.0 \
		and not Modifiers.params(crew.slot, &"defense.armor_broken_stagger").is_empty()


func _crew(net_id: int) -> CrewController:
	return Ids.lookup(net_id) as CrewController if net_id != 0 else null


func _on_npc_killed(_npc_net_id: int, killer_net_id: int, info: Dictionary) -> void:
	var crew: CrewController = _crew(killer_net_id)
	if crew == null or not Net.is_authority():
		return
	if crew.crew_state == Enums.CrewState.DOWNED:
		_self_revive(crew)
	_overkill(crew, StringName(info.get("weapon_id", &"")))


func _on_damage_applied(victim_net_id: int, attacker_net_id: int, info: Dictionary) -> void:
	var crew: CrewController = _crew(attacker_net_id)
	if crew == null or not Net.is_authority() or float(info.get("amount", 0.0)) <= 0.0:
		return
	var npc: NpcBase = Ids.lookup(victim_net_id) as NpcBase
	if npc == null:
		return
	if staggers(crew) and npc.alive and not (npc.enemy_def != null and npc.enemy_def.is_special):
		npc.stun(CombatTweak.data().armor_broken_stagger_s)  # B2 Cornered
	if int(info.get("zone", Enums.HitZone.BODY)) == Enums.HitZone.HEAD:
		_bullseye(crew)


## Overkill: the kill weapon's class against each granted entry's trigger_class.
func _overkill(crew: CrewController, weapon_id: StringName) -> void:
	var def: WeaponDef = ContentDB.weapon(weapon_id) if weapon_id != &"" else null
	if def == null:
		return
	var cls: StringName = Enums.weapon_class_qualifier(def.weapon_class)
	for e: Dictionary in Modifiers.list(crew.slot, &"weapon.kill_damage_buff"):
		if StringName(e.get("trigger_class", &"")) != cls:
			continue
		var key: StringName = &"weapon.damage_mult.all" if bool(e.get("all_weapons", false)) \
			else StringName("weapon.damage_mult.%s" % cls)
		CrewBuffs.of(_runtime).grant(crew.slot, BUFF_OVERKILL, {key: float(e.get("damage_mult", 1.0))},
			float(e.get("duration", 0.0)))


func _bullseye(crew: CrewController) -> void:
	var p: Dictionary = Modifiers.params(crew.slot, &"defense.bullseye")
	var h: CrewHealth = crew.health
	if p.is_empty() or h == null or _bullseye_cd.get(crew.slot, 0.0) > 0.0 or crew.crew_state != Enums.CrewState.NORMAL:
		return
	h.armor = minf(h.armor + float(p.get("armor", 0.0)), h.max_armor)
	_bullseye_cd[crew.slot] = float(p.get("cooldown", 0.0))


## Messiah: a kill from the floor gets the killer up while charges last.
func _self_revive(crew: CrewController) -> void:
	var charges: int = int(Modifiers.add(crew.slot, &"defense.self_revive_charges"))
	if crew.health == null or revives_used.get(crew.slot, 0) >= charges:
		return
	revives_used[crew.slot] = revives_used.get(crew.slot, 0) + 1
	crew.health.revive(crew.slot)
	Log.info(&"combat", "slot %d self-revived by a kill (%d/%d)" % [crew.slot, revives_used[crew.slot], charges])


## DeployablePrefab hook (null-safe: no runtime, nothing): `crew` used a doctor bag at `bag`.
static func doctor_bag_used(bag: Node, crew: CrewController) -> void:
	var t: SkillTriggers = of(HeistRuntime.of(bag))
	if t != null:
		t.on_doctor_bag(crew)


## DeployablePrefab hook (null-safe): `user` took `share` of a loadout from `owner_slot`'s ammo bag at `bag`.
static func ammo_bag_used(bag: Node, user: CrewController, owner_slot: int, share: float) -> void:
	var t: SkillTriggers = of(HeistRuntime.of(bag))
	if t != null:
		t.on_ammo_bag(user, owner_slot, share)


## DeployablePrefab: `crew` used a doctor bag (Messiah Aced refills the self-revive charges).
func on_doctor_bag(crew: CrewController) -> void:
	if crew != null and Modifiers.flag(crew.slot, &"defense.self_revive_refill_on_doctor_bag"):
		revives_used[crew.slot] = 0


## DeployablePrefab: `user` took `share` (0..1 of a full loadout) from `owner_slot`'s ammo bag (Bulletstorm).
func on_ammo_bag(user: CrewController, owner_slot: int, share: float) -> void:
	var p: Dictionary = Modifiers.params(owner_slot, &"deploy.ammo_bag_bulletstorm")
	var cap: float = float(p.get("max_duration", 0.0))
	if user == null or cap <= 0.0 or share <= 0.0:
		return
	var dur: float = minf(float(p.get("base_duration", 0.0)) + cap * share, cap)
	CrewBuffs.of(_runtime).grant(user.slot, BUFF_BULLETSTORM, {}, dur, [CrewBuffs.TAG_FREE_AMMO])


## CrewHealth.revive: `crew` got up, revived by `by_slot` (Numbing Agent on the reviver, the post-revive buffs).
func revived(crew: CrewController, by_slot: int) -> void:
	var buffs: CrewBuffs = CrewBuffs.of(_runtime)
	var rp: Dictionary = Modifiers.params(by_slot, &"ability.revive_target_buff") if by_slot != crew.slot else {}
	if not rp.is_empty():
		buffs.grant(crew.slot, BUFF_REVIVE_TARGET, {&"defense.damage_taken_mult": float(rp.get("damage_taken_mult", 1.0))},
			float(rp.get("duration", 0.0)))
	var values: Dictionary = {}
	var dur: float = 0.0
	for e: Dictionary in Modifiers.list(crew.slot, &"defense.post_revive_buff"):
		dur = maxf(dur, float(e.get("duration", 0.0)))
		for pair: Array in [[&"weapon.reload_speed_mult", "reload_mult"], [&"weapon.swap_speed_mult", "swap_mult"],
				[&"movement.speed_mult", "move_mult"], [&"defense.damage_taken_mult", "damage_taken_mult"]]:
			values[pair[0]] = float(values.get(pair[0], 1.0)) * float(e.get(pair[1], 1.0))
	if dur > 0.0:
		buffs.grant(crew.slot, BUFF_POST_REVIVE, values, dur)


## CrewHealth hook (null-safe): `crew` was revived by `by_slot`.
static func on_revived(crew: CrewController, by_slot: int) -> void:
	var t: SkillTriggers = of(HeistRuntime.of(crew)) if crew != null else null
	if t != null:
		t.revived(crew, by_slot)


## CrewHealth hook (null-safe): Triage's damage multiplier for `crew`.
static func reviving_mult(crew: CrewController) -> float:
	var rt: HeistRuntime = HeistRuntime.of(crew) if crew != null else null
	var t: SkillTriggers = rt.service(SERVICE) as SkillTriggers if rt != null else null
	return t.reviving_damage_mult(crew) if t != null else 1.0


## DeployablePrefab hook (null-safe): `user` used `kit` (a doctor bag or first-aid kit): its owner's Bedside Manner.
static func medical_used(kit: DeployablePrefab, user: CrewController) -> void:
	var t: SkillTriggers = of(HeistRuntime.of(kit))
	var p: Dictionary = Modifiers.params(kit.owner_slot, &"deploy.medical_user_buff")
	if t == null or user == null or p.is_empty():
		return
	CrewBuffs.of(t._runtime).grant(user.slot, BUFF_MEDICAL,
		{&"defense.damage_taken_mult": float(p.get("damage_taken_mult", 1.0))}, float(p.get("duration", 0.0)))


## Playing Possum: an alive enemy within POSSUM_SIGHT_M has line of sight to the downed `crew`.
static func seen_by_enemy(crew: CrewController) -> bool:
	var at: Vector3 = crew.global_position + Vector3.UP * 0.4
	for n: Node in crew.get_tree().get_nodes_in_group(G.ENEMY):
		var npc: NpcBase = n as NpcBase
		if npc == null or not npc.alive or npc.global_position.distance_to(at) > POSSUM_SIGHT_M:
			continue
		if CombatSystem.has_los(npc, npc.global_position + Vector3.UP * 1.6, at, [npc, crew]):
			return true
	return false


## CrewHealth: `crew`'s armor just broke (Second Wind).
func armor_broken(crew: CrewController) -> void:
	var p: Dictionary = Modifiers.params(crew.slot, &"defense.armor_break_speed_buff")
	var dur: float = float(p.get("duration", 0.0))
	if dur <= 0.0:
		return
	var slots: Array[int] = [crew.slot]
	if bool(p.get("team", false)) and _runtime != null:
		slots.clear()
		for c: CrewController in _runtime.crew_members():
			slots.append(c.slot)
	for s: int in slots:
		CrewBuffs.of(_runtime).grant(s, BUFF_SECOND_WIND, {&"movement.speed_mult": float(p.get("move_mult", 1.0))}, dur)


## CrewHealth hook (null-safe): `crew`'s armor broke.
static func armor_broke(crew: CrewController) -> void:
	var t: SkillTriggers = of(HeistRuntime.of(crew)) if crew != null else null
	if t != null:
		t.armor_broken(crew)


## A {per_step, points_per_step, threshold_dr, max} grant for `crew`'s detection risk: per_step per points_per_step
## points under threshold_dr, at most max (Low Blow, Sneaky Bastard).
static func per_concealment(crew: CrewController, key: StringName) -> float:
	var p: Dictionary = Modifiers.params(crew.slot, key) if crew != null else {}
	var pps: float = float(p.get("points_per_step", 0.0))
	if p.is_empty() or pps <= 0.0 or crew.loadout == null:
		return 0.0
	var under: float = maxf(float(p.get("threshold_dr", 0.0)) - float(crew.loadout.detection_risk), 0.0)
	return minf(floorf(under / pps) * float(p.get("per_step", 0.0)), float(p.get("max", 0.0)))


## B2: `crew`'s crit chance 0..1.
static func crit_chance(crew: CrewController) -> float:
	if crew == null:
		return 0.0
	return clampf(Modifiers.add(crew.slot, &"weapon.crit_chance_add")
		+ per_concealment(crew, &"weapon.crit_per_concealment"), 0.0, 1.0)


## B2: roll a crit for `crew`'s hit (server; GameRng "crit"). The damage multiplier when it crits, else 1.
static func roll_crit(crew: CrewController) -> float:
	var c: float = crit_chance(crew)
	if c <= 0.0 or GameRng.stream(&"crit").randf() >= c:
		return 1.0
	return CombatTweak.data().crit_damage_mult


## B2: dodge `crew` adds from its concealment (Sneaky Bastard) and from sprinting (Duck and Cover).
static func dodge_add(crew: CrewController) -> float:
	if crew == null:
		return 0.0
	var d: float = per_concealment(crew, &"defense.dodge_per_concealment")
	if crew.sprinting:
		d += Modifiers.add(crew.slot, &"defense.sprint_dodge_add")
	return d


## Berserker: the damage multiplier for `crew` now (melee, or ranged with `ranged`), 1.0 above the threshold.
static func berserk_mult(crew: CrewController, ranged: bool) -> float:
	if crew == null or crew.health == null:
		return 1.0
	var p: Dictionary = Modifiers.params(crew.slot, &"defense.berserk")
	var thr: float = float(p.get("threshold", 0.0))
	var h: CrewHealth = crew.health
	if thr <= 0.0 or h.max_health <= 0.0:
		return 1.0
	var frac: float = clampf(h.health / h.max_health, 0.0, 1.0)
	if frac >= thr:
		return 1.0
	var top: float = float(p.get("ranged_max_damage_mult" if ranged else "max_damage_mult", 1.0))
	return lerpf(1.0, top, 1.0 - frac / thr)
