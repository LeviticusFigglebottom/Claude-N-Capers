## Wrecker brain (A3-01b, L4.6; PD2 Bulldozer). Owner: ENV A. Server only. Child `Brain` of
## npc_wrecker.tscn (siblings Motor, Gunner, Weakpoints = WreckerArmor). Variants Wrecker-G / -B / -S / -M
## (pump / semi-auto / LMG / minigun) are EnemyDefs enemy.wrecker_g|_b|_s|_m on the same scene (fire
## numbers in EnemyDef.params; -M: 2x HP, spin_up_s / spin_down_s for NpcGunner, Cataclysm-only group
## group.special_wrecker_m); all count toward the `enemy.wrecker` special limit (PoliceSpecialKit.limit_key).
## Extends the PoliceBrain pattern with:
## - Pressure: no cover, no flank; a short standoff band (wrecker_standoff_*) so it keeps walking into
##   the crew at EnemyDef.move_speed while its gunner fires (NpcGunner fires while moving).
## - Shield formation: with an allied Bulwark within formation_join_m it walks behind it instead.
## - Presentation [R]: cue.wrecker_roar on activation (intro), cue.wrecker_step every
##   wrecker_step_interval_s while moving (heavy footstep loop; C's cue def is audible 30 m).
## - Data (EnemyDef.params): stun_immune (NpcBase.stun ignores ECM feedback), explosive_mult 1.1
##   (NpcHitRules), plate_health [150, 160] (WreckerArmor). special_spawned(&"wrecker") [R].
class_name WreckerBrain
extends PoliceBrain

@export var special_type: StringName = &"wrecker"
@export var special_tweak: HeavySpecialTweak

var roared: bool = false
var steps: int = 0

var _step_left: float = 0.0


func _ready() -> void:
	if special_tweak == null:
		special_tweak = HeavySpecialTweak.data()
	super._ready()
	if tweak != null:
		tweak = tweak.duplicate() as PoliceTweak
		tweak.standoff_min_m = special_tweak.wrecker_standoff_min_m
		tweak.standoff_pref_m = special_tweak.wrecker_standoff_pref_m
		tweak.standoff_max_m = special_tweak.wrecker_standoff_max_m
		tweak.flank_chance = 0.0


func _start() -> void:
	super._start()
	if _started:
		PoliceSpecialKit.announce(_npc, special_type)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _active or _npc == null or not _npc.alive:
		return
	var hv: float = Vector2(_npc.velocity.x, _npc.velocity.z).length()
	if hv < special_tweak.wrecker_moving_speed_m_s:
		_step_left = 0.0
		return
	_step_left -= delta
	if _step_left <= 0.0:
		_step_left = special_tweak.wrecker_step_interval_s
		steps += 1
		PoliceSpecialKit.cue(_npc, &"cue.wrecker_step")


func armor() -> WreckerArmor:
	return _npc.get_node_or_null("Weakpoints") as WreckerArmor if _npc != null else null


# --- PoliceBrain overrides -------------------------------------------------------------------

func _activate() -> void:
	super._activate()
	if not roared:
		roared = true
		PoliceSpecialKit.cue(_npc, &"cue.wrecker_roar", _npc.head_position())


func _find_cover(_t: Node3D) -> TacticalPoint:
	return null  # Wreckers never take cover


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
