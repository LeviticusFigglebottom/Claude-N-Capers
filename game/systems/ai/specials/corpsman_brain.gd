## Corpsman brain (A3-01b, L4.8; PD2 Medic). Owner: ENV A. Server only. Child `Brain` of npc_corpsman.tscn.
## Extends the PoliceBrain pattern (and takes the spot behind an allied Bulwark when one is near).
## Heal / revive (numbers in HeavySpecialTweak, ◇ where not PD2):
## - ONE ally within corpsman_radius_m (7 m, 3D, through walls: no LOS), then corpsman_cooldown_s (3 s).
## - Revive: a hit that would kill an ally in range of a ready Corpsman leaves it alive at full health
##   instead (NpcBase.take_hit -> NpcHitRules.lethal_intercept -> try_revive; out.healed_by/revived).
## - Heal: a ready Corpsman also heals the most hurt living ally in range below corpsman_heal_below_frac.
## - Medics don't heal medics (allies whose Brain is a CorpsmanBrain are skipped). Allies are alive
##   enemy-side NPCs (group G.ENEMY) not surrendered / tied / converted (NpcBase.BLIND_STATES).
## - Neither medic nor target may move or shoot for corpsman_heal_lock_s: the medic's brain holds
##   (mode &"heal", anim heal_ally); the target is held with NpcBase.stun_left for the same time (ticked
##   by the medic; released early if the medic dies).
## - Presentation: cue.corpsman_heal [R] at the target; the green outline is exposed as
##   CorpsmanBrain.is_outlined(npc) / outline_target / outline_left (corpsman_outline_s).
## special_spawned(&"corpsman") [R] on start.
class_name CorpsmanBrain
extends PoliceBrain

signal healed(target: NpcBase, revived: bool)

const UNIT_GROUP: StringName = &"corpsman_unit"

@export var special_type: StringName = &"corpsman"
@export var special_tweak: HeavySpecialTweak

var cooldown_left: float = 0.0
var heals: int = 0
var revives: int = 0
## Unit being healed (lock running) and the unit showing the green outline.
var heal_target: NpcBase = null
var heal_left: float = 0.0
var outline_target: NpcBase = null
var outline_left: float = 0.0


func _ready() -> void:
	if special_tweak == null:
		special_tweak = HeavySpecialTweak.data()
	super._ready()
	if _npc != null:
		_npc.add_to_group(UNIT_GROUP)


func _start() -> void:
	super._start()
	if _started:
		PoliceSpecialKit.announce(_npc, special_type)


## Server: L4.8 revive hook. `npc` would die from the hit described by `out`: a ready Corpsman in
## range saves it (full health). Returns true when saved.
static func try_revive(npc: NpcBase, out: Dictionary) -> bool:
	if npc == null or not Net.is_authority() or not npc.is_inside_tree() or is_medic(npc):
		return false
	for n: Node in npc.get_tree().get_nodes_in_group(UNIT_GROUP):
		var medic: NpcBase = n as NpcBase
		var b: CorpsmanBrain = medic.get_node_or_null("Brain") as CorpsmanBrain if medic != null else null
		if b != null and b.can_heal(npc):
			b.start_heal(npc, true)
			out["healed_by"] = medic.net_id
			out["revived"] = true
			return true
	return false


static func is_medic(npc: Node) -> bool:
	return npc != null and npc.get_node_or_null("Brain") is CorpsmanBrain


## The healed-unit outline (L4.8 green outline) is showing on `npc`.
static func is_outlined(npc: NpcBase) -> bool:
	if npc == null or not npc.is_inside_tree():
		return false
	for n: Node in npc.get_tree().get_nodes_in_group(UNIT_GROUP):
		var b: CorpsmanBrain = n.get_node_or_null("Brain") as CorpsmanBrain
		if b != null and b.outline_target == npc and b.outline_left > 0.0:
			return true
	return false


func is_ready_to_heal() -> bool:
	return _started and _npc != null and _npc.alive and cooldown_left <= 0.0 and heal_left <= 0.0 \
		and not _npc.is_stunned() and ACTIVE_STATES.has(_npc.alert_state)


## Can this Corpsman heal / revive `ally` right now (ready, in range, a valid non-medic ally)?
func can_heal(ally: NpcBase) -> bool:
	if not is_ready_to_heal() or not _is_ally(ally):
		return false
	return ally.global_position.distance_to(_npc.global_position) <= special_tweak.corpsman_radius_m


## Server: heal `ally` to full now and start the lock / cooldown (cue.corpsman_heal [R]).
func start_heal(ally: NpcBase, revived: bool = false) -> void:
	var tw: HeavySpecialTweak = special_tweak
	ally.health = ally.max_health
	cooldown_left = tw.corpsman_cooldown_s
	heal_left = tw.corpsman_heal_lock_s
	heal_target = ally
	outline_target = ally
	outline_left = tw.corpsman_outline_s
	ally.stun_left = maxf(ally.stun_left, tw.corpsman_heal_lock_s)  # lock: no move / shoot
	if revived:
		revives += 1
	else:
		heals += 1
	_hold_for_heal()
	PoliceSpecialKit.cue(_npc, &"cue.corpsman_heal", ally.head_position())
	healed.emit(ally, revived)


func _physics_process(delta: float) -> void:
	if not _started or _npc == null or not _npc.alive or not Net.is_authority():
		return
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	outline_left = maxf(outline_left - delta, 0.0)
	if heal_left > 0.0:
		heal_left -= delta
		if heal_target != null and is_instance_valid(heal_target):
			heal_target.tick_stun(delta)
		_hold_for_heal()
		if heal_left <= 0.0:
			_end_heal()
		return
	super._physics_process(delta)
	if _active and is_ready_to_heal():
		var ally: NpcBase = _most_hurt_ally()
		if ally != null:
			start_heal(ally, false)


func _hold_for_heal() -> void:
	wants_to_fire = false
	mode = &"heal"
	anim_hint = &"heal_ally"
	_motor.stop()
	if heal_target != null and is_instance_valid(heal_target):
		_motor.face_point(heal_target.global_position)


func _end_heal() -> void:
	heal_left = 0.0
	if heal_target != null and is_instance_valid(heal_target) and heal_target.stun_left <= 0.05:
		heal_target.stun_left = 0.0
	heal_target = null
	mode = &"idle"


func _most_hurt_ally() -> NpcBase:
	var best: NpcBase = null
	var best_frac: float = special_tweak.corpsman_heal_below_frac
	for n: Node in get_tree().get_nodes_in_group(G.ENEMY):
		var a: NpcBase = n as NpcBase
		if a == null or not can_heal(a) or a.max_health <= 0.0:
			continue
		var frac: float = a.health / a.max_health
		if frac < best_frac:
			best_frac = frac
			best = a
	return best


func _is_ally(a: NpcBase) -> bool:
	return a != null and is_instance_valid(a) and a != _npc and a.alive and a.is_in_group(G.ENEMY) \
		and not NpcBase.BLIND_STATES.has(a.alert_state) and not is_medic(a)


# --- PoliceBrain overrides -------------------------------------------------------------------

func _tick_move(delta: float) -> void:
	var t: Node3D = combat_target as Node3D
	var spot: Vector3 = PoliceSpecialKit.spot_behind_bulwark(_npc)
	if t != null and spot != Vector3.INF:
		if _tick_cuff(t):
			return
		if _flat(spot - _npc.global_position).length() > tweak.arrive_m:
			_move_to(spot, &"shield_follow")
		else:
			_hold(t.global_position)
		return
	super._tick_move(delta)


func _on_died(info: Dictionary, killer_net_id: int) -> void:
	if heal_target != null and is_instance_valid(heal_target) and heal_target.stun_left <= heal_left + 0.05:
		heal_target.stun_left = 0.0  # release the lock early
	heal_target = null
	heal_left = 0.0
	outline_left = 0.0
	_npc.remove_from_group(UNIT_GROUP)
	super._on_died(info, killer_net_id)
