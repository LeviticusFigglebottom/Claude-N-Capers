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
##     max); roll_crit() on GameRng "crit" (CombatSystem bullets, CrewMelee) sets info.crit: the target then applies
##     its HEAD multiplier on any zone (D-027 QB-29, as in PD2; NpcBase).
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
## Batch 4b (combat triggers; the weapon class comes from the hit's / kill's weapon_id, "melee" for melee):
##   weapon.kill_reload_buff [LIST] {trigger auto_kills / melee_kill / headshot_kill, kills, classes, reload_mult,
##     duration, min_mult, mag_falloff, mag_falloff_from} (Run and Gun, Wind Up, Reload Rhythm): `kills` qualifying
##     kills give weapon.reload_speed_mult x reload_mult (falling mag_falloff per round of magazine past
##     mag_falloff_from, not below min_mult) for `duration` s, or (duration 0) until the next reload ends.
##   weapon.hit_stack_buff [LIST] {class, stat damage / accuracy, per_hit, max_stacks, duration} (Hot Streak, Rhythm):
##     each hit with the class adds a stack (damage x (1 + per_hit x stacks), or spread x (1 - per_hit x stacks)).
##   weapon.headshot_refund {classes, headshots, window, refund} (Economy): that many headshots within `window` s put
##     `refund` rounds back in the magazine.
##   weapon.graze {class, radius, frac, headshot_kill_frac} (Grazing Fire): a hit with the class deals frac (a headshot
##     kill: headshot_kill_frac) of its damage to the other enemies within radius m of the target.
##   weapon.stagger_chance_add [ADD, class] (Knockdown): the chance a hit stuns a non-special enemy for
##     CombatTweak.skill_stagger_s.
##   defense.outnumbered {enemies, radius, damage_mult, damage_taken_mult, duration} (Outnumbered): with `enemies`+
##     alive enemies within radius m, damage x damage_mult and damage taken x damage_taken_mult, held `duration` s.
##   (weapon.body_expertise: CombatSystem / NpcBase; defense.flashbang_duration_mult: CrewHealth.flash.)
## Batch 6 (hostages, converts, marks):
##   ability.convert_owner_buff {move_mult, health_mult} (Accomplice): while the holder owns a living converted enemy,
##     move x move_mult and max health x health_mult (CrewBuffs "accomplice", refreshed every tick).
##   ability.hostage_regen {per_hostage, max_hostages, interval} (Leverage): every `interval` s while standing, heal
##     per_hostage x min(hostages, max_hostages) of max health.
##   ability.stockholm (Captive Audience Aced): a downed holder is revived by the nearest tied hostage within
##     STOCKHOLM_M after STOCKHOLM_DELAY_S ◇ (PD2: when asked); each hostage does it once.
##   stealth.noise_intimidates_civilians (Captive Audience): the holder's gunfire intimidates civilians within the
##     shout range (as a shout: CivilianBrain.on_shouted); ShoutSystem also widens its civilian range.
##   stealth.mark_by_aim (Price Tag Aced): aiming at a markable enemy for MARK_AIM_S marks it (no shout).
##   (stealth.mark_damage_bonus_mult / mark_far_damage_mult: StealthDirector.mark_damage_mult, the marker's skill.)
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
const BUFF_OUTNUMBERED: StringName = &"outnumbered"
const BUFF_ACCOMPLICE: StringName = &"accomplice"
const STOCKHOLM_M: float = 15.0
const STOCKHOLM_DELAY_S: float = 3.0
## Seconds of aim on the same markable enemy that mark it (Price Tag Aced) ◇.
const MARK_AIM_S: float = 0.5
const META_STOCKHOLM_USED: StringName = &"stockholm_used"
## CrewBuffs tag of a kill reload buff that lasts until the next reload ends (duration 0).
const TAG_NEXT_RELOAD: StringName = &"next_reload"
const NEXT_RELOAD_CAP_S: float = 600.0
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
## "slot:entry" -> qualifying kills counted (kill reload buffs) / hit stacks
var _kill_counts: Dictionary[String, int] = {}
var _stacks: Dictionary[String, int] = {}
## slot -> clock times of qualifying headshots (Economy)
var _headshots: Dictionary[int, Array] = {}
var _clock: float = 0.0
## slot -> seconds until the next hostage regen tick (Leverage)
var _regen_left: Dictionary[int, float] = {}
## slot -> [target net id, seconds aimed] (Price Tag Aced)
var _aim_mark: Dictionary[int, Array] = {}
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
	EventBus.weapon_fired.connect(_on_weapon_fired)


## Captive Audience: the holder's gunfire intimidates the civilians within the shout range.
func _on_weapon_fired(shooter_net_id: int, _weapon_id: StringName, _suppressed: bool, origin: Vector3) -> void:
	var crew: CrewController = _crew(shooter_net_id)
	if crew == null or not Net.is_authority() or not Modifiers.flag(crew.slot, &"stealth.noise_intimidates_civilians"):
		return
	var r: float = Tweak.stealth().shout_range_m
	for n: Node in _runtime.npcs(&"civilian"):
		var npc: NpcBase = n as NpcBase
		var brain: Node = npc.get_node_or_null(^"Brain") if npc != null else null
		if brain != null and npc.alive and brain.has_method(&"on_shouted") and npc.global_position.distance_to(origin) <= r:
			brain.call(&"on_shouted", crew)


func _tick_accomplice(crew: CrewController) -> void:
	var p: Dictionary = Modifiers.params(crew.slot, &"ability.convert_owner_buff")
	if p.is_empty():
		return
	for n: Node in _runtime.npcs():
		var npc: NpcBase = n as NpcBase
		var ally: ConvertedAllyBrain = npc.get_node_or_null(NodePath(ConvertedAllyBrain.NODE_NAME)) as ConvertedAllyBrain \
			if npc != null and npc.alive else null
		if ally != null and ally.owner_slot == crew.slot:
			CrewBuffs.of(_runtime).grant(crew.slot, BUFF_ACCOMPLICE, {&"movement.speed_mult": float(p.get("move_mult", 1.0)),
				&"defense.health_mult": float(p.get("health_mult", 1.0))}, 0.5)
			return


func _tick_hostage_regen(crew: CrewController, delta: float) -> void:
	var p: Dictionary = Modifiers.params(crew.slot, &"ability.hostage_regen")
	var n: int = mini(TeamModifiers.hostage_count(crew), int(p.get("max_hostages", 0)))
	if p.is_empty() or n <= 0 or crew.health == null or crew.crew_state != Enums.CrewState.NORMAL:
		_regen_left.erase(crew.slot)
		return
	_regen_left[crew.slot] = _regen_left.get(crew.slot, float(p.get("interval", 5.0))) - delta
	if _regen_left[crew.slot] > 0.0:
		return
	_regen_left[crew.slot] = float(p.get("interval", 5.0))
	crew.health.heal(crew.health.max_health * float(p.get("per_hostage", 0.0)) * float(n))


func _tick_stockholm(crew: CrewController) -> void:
	if crew.crew_state != Enums.CrewState.DOWNED or crew.health == null or crew.health.down_s < STOCKHOLM_DELAY_S \
			or not Modifiers.flag(crew.slot, &"ability.stockholm"):
		return
	var best: NpcBase = null
	for n: Node in get_tree().get_nodes_in_group(G.HOSTAGE):
		var h: NpcBase = n as NpcBase
		if h == null or not h.alive or h.has_meta(META_STOCKHOLM_USED) or HeistRuntime.of(h) != _runtime:
			continue
		var d: float = h.global_position.distance_to(crew.global_position)
		if d <= STOCKHOLM_M and (best == null or d < best.global_position.distance_to(crew.global_position)):
			best = h
	if best != null:
		best.set_meta(META_STOCKHOLM_USED, true)
		crew.health.revive(crew.slot)


func _tick_mark_by_aim(crew: CrewController, delta: float) -> void:
	if crew.weapons == null or not crew.weapons.aiming or not Modifiers.flag(crew.slot, &"stealth.mark_by_aim") \
			or _runtime.stealth == null:
		_aim_mark.erase(crew.slot)
		return
	var eye: Vector3 = crew.eye_position()
	var range_m: float = Tweak.stealth().mark_range_m * Modifiers.mult(crew.slot, &"ability.shout_range_mult")
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, eye + crew.aim_direction() * range_m)
	q.exclude = [crew.get_rid()]
	var hit: Dictionary = crew.get_world_3d().direct_space_state.intersect_ray(q)
	var col: Node = hit.get("collider") as Node
	while col != null and not col is NpcBase:
		col = col.get_parent()
	var npc: NpcBase = col as NpcBase
	if npc == null or StealthDirector.mark_kind_of(npc) == &"":
		_aim_mark.erase(crew.slot)
		return
	var prev: Array = _aim_mark.get(crew.slot, [0, 0.0])
	var t: float = float(prev[1]) + delta if int(prev[0]) == npc.net_id else delta
	_aim_mark[crew.slot] = [npc.net_id, t]
	if t >= MARK_AIM_S and not _runtime.stealth.is_marked(npc):
		_runtime.stealth.mark(npc, crew.slot)


func _physics_process(delta: float) -> void:
	for slot: int in _bullseye_cd:
		_bullseye_cd[slot] = maxf(_bullseye_cd[slot] - delta, 0.0)
	_clock += delta
	if not Net.is_authority() or _runtime == null:
		return
	for crew: CrewController in _runtime.crew_members():
		_tick_accomplice(crew)
		_tick_hostage_regen(crew, delta)
		_tick_stockholm(crew)
		_tick_mark_by_aim(crew, delta)
		_tick_outnumbered(crew)
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
	_kill_reload(crew, info)


func _on_damage_applied(victim_net_id: int, attacker_net_id: int, info: Dictionary) -> void:
	var crew: CrewController = _crew(attacker_net_id)
	if crew == null or not Net.is_authority() or float(info.get("amount", 0.0)) <= 0.0:
		return
	var npc: NpcBase = Ids.lookup(victim_net_id) as NpcBase
	if npc == null:
		return
	var special: bool = npc.enemy_def != null and npc.enemy_def.is_special
	if staggers(crew) and npc.alive and not special:
		npc.stun(CombatTweak.data().armor_broken_stagger_s)  # B2 Cornered
	var head: bool = int(info.get("zone", Enums.HitZone.BODY)) == Enums.HitZone.HEAD
	if head:
		_bullseye(crew)
	if bool(info.get("graze", false)):
		return  # B4b: a graze hit triggers nothing more
	var cls: StringName = weapon_class_of(info)
	var stagger: float = Modifiers.add(crew.slot, &"weapon.stagger_chance_add", cls)
	if npc.alive and not special and stagger > 0.0 and GameRng.stream(&"stagger").randf() < stagger:
		npc.stun(CombatTweak.data().skill_stagger_s)  # B4b Knockdown
	_hit_stacks(crew, cls)
	if head:
		_headshot_refund(crew, cls, StringName(info.get("weapon_id", &"")))
	_graze(crew, npc, info, cls, head)


## B4b: the weapon class of a hit / kill ("melee" for a melee weapon or melee damage, &"" when unknown).
static func weapon_class_of(info: Dictionary) -> StringName:
	var id: StringName = StringName(info.get("weapon_id", &""))
	var def: WeaponDef = ContentDB.weapon(id) if id != &"" else null
	if def != null:
		return Enums.weapon_class_qualifier(def.weapon_class)
	if int(info.get("type", -1)) == Enums.DamageType.MELEE or (id != &"" and ContentDB.melee(id) != null):
		return &"melee"
	return &""


func _kill_reload(crew: CrewController, info: Dictionary) -> void:
	var cls: StringName = weapon_class_of(info)
	var head: bool = int(info.get("zone", Enums.HitZone.BODY)) == Enums.HitZone.HEAD
	var entries: Array[Dictionary] = Modifiers.list(crew.slot, &"weapon.kill_reload_buff")
	for i: int in entries.size():
		var e: Dictionary = entries[i]
		var classes: Array = e.get("classes", [])
		var in_class: bool = classes.is_empty() or classes.has(String(cls))
		var ok: bool = false
		match String(e.get("trigger", "")):
			"auto_kills":
				var def: WeaponDef = ContentDB.weapon(StringName(info.get("weapon_id", &"")))
				ok = in_class and def != null and def.fire_modes.has(&"auto")
			"melee_kill":
				ok = cls == &"melee"
			"headshot_kill":
				ok = head and in_class
		if not ok:
			continue
		var k: String = "%d:%s:%s" % [crew.slot, e.get("_source", ""), e.get("trigger", "")]
		_kill_counts[k] = _kill_counts.get(k, 0) + 1
		if _kill_counts[k] < int(e.get("kills", 1)):
			continue
		_kill_counts[k] = 0
		var mag: int = crew.weapons.mag_size(crew.weapons.equipped_slot) if crew.weapons != null else 0
		var past: float = maxf(float(mag - int(e.get("mag_falloff_from", 0))), 0.0)
		var mult: float = maxf(float(e.get("reload_mult", 1.0)) - float(e.get("mag_falloff", 0.0)) * past,
			float(e.get("min_mult", 1.0)))
		var dur: float = float(e.get("duration", 0.0))
		CrewBuffs.of(_runtime).grant(crew.slot, StringName("kill_reload.%s" % e.get("_source", i)), {&"weapon.reload_speed_mult": mult},
			dur if dur > 0.0 else NEXT_RELOAD_CAP_S, [] if dur > 0.0 else [TAG_NEXT_RELOAD])


## CrewWeapons hook (null-safe): `crew` finished a reload: the "next reload" kill buffs are spent.
static func reload_done(crew: CrewController) -> void:
	var rt: HeistRuntime = HeistRuntime.of(crew) if crew != null else null
	var buffs: CrewBuffs = rt.service(CrewBuffs.SERVICE) as CrewBuffs if rt != null else null
	if buffs == null or not Net.is_authority():
		return
	for source: StringName in (buffs._buffs.get(crew.slot, {}) as Dictionary).keys():
		if (((buffs._buffs[crew.slot] as Dictionary)[source] as Dictionary).get("tags", []) as Array).has(TAG_NEXT_RELOAD):
			buffs.end(crew.slot, source)


func _hit_stacks(crew: CrewController, cls: StringName) -> void:
	var entries: Array[Dictionary] = Modifiers.list(crew.slot, &"weapon.hit_stack_buff")
	var buffs: CrewBuffs = CrewBuffs.of(_runtime)
	for i: int in entries.size():
		var e: Dictionary = entries[i]
		if StringName(e.get("class", &"")) != cls:
			continue
		var source: StringName = StringName("hit_stack.%s.%s" % [e.get("_source", i), e.get("stat", "")])
		var k: String = "%d:%s" % [crew.slot, source]
		var n: int = mini((_stacks.get(k, 0) if buffs.active(crew.slot, source) else 0) + 1, int(e.get("max_stacks", 1)))
		_stacks[k] = n
		var per: float = float(e.get("per_hit", 0.0)) * float(n)
		var values: Dictionary = {StringName("weapon.damage_mult.%s" % cls): 1.0 + per} if String(e.get("stat", "")) == "damage" \
			else {StringName("weapon.spread_mult.%s" % cls): maxf(1.0 - per, 0.1)}
		buffs.grant(crew.slot, source, values, float(e.get("duration", 0.0)))


func _headshot_refund(crew: CrewController, cls: StringName, weapon_id: StringName) -> void:
	var p: Dictionary = Modifiers.params(crew.slot, &"weapon.headshot_refund")
	if p.is_empty() or not (p.get("classes", []) as Array).has(String(cls)) or crew.weapons == null:
		return
	var times: Array = _headshots.get(crew.slot, [])
	times.append(_clock)
	var window: float = float(p.get("window", 0.0))
	times = times.filter(func(t: float) -> bool: return _clock - t <= window)
	_headshots[crew.slot] = times
	if times.size() < int(p.get("headshots", 1)):
		return
	_headshots[crew.slot] = []
	var w: CrewWeapons = crew.weapons
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		if w.has_weapon(ws) and w.weapon_id(ws) == weapon_id:
			w.set_ammo(ws, mini(w.mag(ws) + int(p.get("refund", 1)), w.mag_size(ws)), w.reserve(ws))
			return


func _graze(crew: CrewController, npc: NpcBase, info: Dictionary, cls: StringName, head: bool) -> void:
	var p: Dictionary = Modifiers.params(crew.slot, &"weapon.graze")
	if p.is_empty() or StringName(p.get("class", &"")) != cls:
		return
	var kill: bool = bool(info.get("killed", false)) or not npc.alive  # damage_applied fires before alive flips
	var frac: float = float(p.get("headshot_kill_frac" if head and kill else "frac", 0.0))
	var dmg: float = float(info.get("amount", 0.0)) * frac
	var radius: float = float(p.get("radius", 0.0))
	if dmg <= 0.0 or radius <= 0.0:
		return
	for n: Node in get_tree().get_nodes_in_group(G.ENEMY):
		var other: NpcBase = n as NpcBase
		if other == null or other == npc or not other.alive or other.global_position.distance_to(npc.global_position) > radius:
			continue
		var g: Dictionary = Damage.info(dmg, Enums.DamageType.BULLET, Enums.HitZone.BODY, StringName(info.get("weapon_id", &"")),
			other.global_position, Vector3.ZERO, crew.net_id)
		g["graze"] = true
		CombatSystem.deliver_hit(other, g, crew.net_id)


## Outnumbered: refreshed every tick the holder has `enemies`+ alive enemies within radius m.
func _tick_outnumbered(crew: CrewController) -> void:
	var p: Dictionary = Modifiers.params(crew.slot, &"defense.outnumbered")
	if p.is_empty() or crew.crew_state != Enums.CrewState.NORMAL:
		return
	var radius: float = float(p.get("radius", 0.0))
	var n: int = 0
	for node: Node in get_tree().get_nodes_in_group(G.ENEMY):
		var npc: NpcBase = node as NpcBase
		if npc != null and npc.alive and npc.global_position.distance_to(crew.global_position) <= radius:
			n += 1
	if n < int(p.get("enemies", 1)):
		return
	CrewBuffs.of(_runtime).grant(crew.slot, BUFF_OUTNUMBERED, {&"weapon.damage_mult.all": float(p.get("damage_mult", 1.0)),
		&"defense.damage_taken_mult": float(p.get("damage_taken_mult", 1.0))}, float(p.get("duration", 0.0)))


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


## B2: roll a crit for `crew`'s hit (server; GameRng "crit"). True: the hit is a crit (info.crit, D-027 QB-29).
static func roll_crit(crew: CrewController) -> bool:
	var c: float = crit_chance(crew)
	return c > 0.0 and GameRng.stream(&"crit").randf() < c


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
