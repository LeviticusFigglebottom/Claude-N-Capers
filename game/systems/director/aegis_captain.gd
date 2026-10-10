## Commander Brandt + Aegis squad (A3-02, L4.9; PD2 Captain Winters + Phalanx). Owner: ENV A.
## Server only. Child `AegisCaptain` of AssaultDirector, which schedules him (once per heist day,
## difficulty >= DirectorTweak.captain_min_difficulty, D-015: also in solo) and calls `summon()`.
## Rules (numbers in DirectorTweak "Commander Brandt + Aegis"):
## - arrives at the valid police spawn point nearest the crew with `aegis_shields` shields
##   (enemy.bulwark when its EnemyDef exists, else the enemy.aegis placeholder), all flagged META_AEGIS.
## - while he is on the map (`locks_assault()`) the director never enters FADE.
## - once in position (captain_settle_s after arrival) every enemy (roles police/special) takes
##   damage x (1 - resistance): base 10%, +5% every 5 s, up to 50%; cue.aegis_pulse on every step.
## - he and his shields take at most captain_hit_cap_frac of max HP per hit (x6 from explosives);
##   no flinch (EnemyDef.params.no_flinch / META_NO_FLINCH for flinch logic); he cannot be killed.
## - retreats at captain_retreat_hp_frac HP or when <= captain_retreat_shields shields remain:
##   captain_retreated [R], resistance 0, the assault resumes; the remaining shields break up into
##   normal units (PD2 phalanx breakup) and Brandt leaves the map after captain_despawn_s.
## The NpcBase hit hook reaches `modify_hit()` through AssaultDirector.modify_npc_hit().
class_name AegisCaptain
extends Node

signal arrived(brandt: NpcBase)
signal retreated(brandt: NpcBase, reason: StringName)
signal resistance_changed(resistance: float)

const META_AEGIS: StringName = &"aegis_unit"
const META_CAPTAIN: StringName = &"aegis_captain"
const META_NO_FLINCH: StringName = &"no_flinch"
const CUE_ARRIVAL: StringName = &"cue.brandt_arrival"
const CUE_PULSE: StringName = &"cue.aegis_pulse"
const BULWARK_ID: StringName = &"enemy.bulwark"
const BRANDT_PATH: String = "res://systems/ai/data/enemies/brandt.tres"
const AEGIS_PATH: String = "res://systems/ai/data/enemies/aegis.tres"
const RETREAT_HP: StringName = &"hp"
const RETREAT_FORMATION: StringName = &"formation"

var director: AssaultDirector = null
var brandt: NpcBase = null
var shields: Array[NpcBase] = []
## On the map and not retreating (locks the assault).
var active: bool = false
var in_position: bool = false
## Current damage resistance for every enemy (0..aegis_resist_max).
var resistance: float = 0.0
## Once per heist day (a HeistRuntime is one day).
var spawned_today: bool = false
var retreat_reason: StringName = &""

var _t_active: float = 0.0
var _step_t: float = 0.0


func setup(p_director: AssaultDirector) -> void:
	director = p_director


func tw() -> DirectorTweak:
	return director.tweak


## L4.9 + D-015: difficulty threshold only (crew size and solo do not matter). Runtime option
## "captain": false disables him (tests, modes).
func eligible() -> bool:
	var rt: HeistRuntime = director.runtime()
	if rt == null or not bool(rt.options.get("captain", true)):
		return false
	return rt.difficulty >= tw().captain_min_difficulty


func locks_assault() -> bool:
	return active


## Server: spawn Brandt + squad at the valid spawn point nearest the crew. False when he already
## came today, is on the map, or no point is valid right now (the director retries).
func summon() -> bool:
	if active or spawned_today or not Net.is_authority() or director == null:
		return false
	var points: Array[Node3D] = director.valid_spawn_points()
	if points.is_empty():
		return false
	var point: Node3D = points[0]
	var cdef: EnemyDef = captain_def()
	if cdef == null:
		Log.error(&"director", "no EnemyDef for Commander Brandt")
		return false
	brandt = director.spawn_enemy(cdef, point.global_transform, point, {"captain": true})
	if brandt == null:
		return false
	brandt.set_meta(META_CAPTAIN, true)
	brandt.set_meta(META_NO_FLINCH, true)
	brandt.damaged.connect(_on_brandt_damaged)
	shields.clear()
	var sdef: EnemyDef = shield_def()
	var n: int = maxi(tw().aegis_shields, 0)
	for i: int in range(n):
		var ang: float = TAU * float(i) / float(maxi(n, 1))
		var xf: Transform3D = point.global_transform
		xf.origin += Vector3(cos(ang), 0.0, sin(ang)) * tw().aegis_spread_m
		var s: NpcBase = director.spawn_enemy(sdef, xf, point, {"aegis": true}) if sdef != null else null
		if s == null:
			continue
		s.set_meta(META_AEGIS, true)
		s.set_meta(META_NO_FLINCH, true)
		s.died.connect(_on_shield_died.unbind(2))
		shields.append(s)
	spawned_today = true
	active = true
	in_position = false
	resistance = 0.0
	retreat_reason = &""
	_t_active = 0.0
	_step_t = 0.0
	Log.info(&"director", "Commander Brandt arrived with %d Aegis shields" % shields.size())
	EventBus.captain_arrived.emit(brandt.net_id)
	Net.replicate_event(&"captain_arrived", [brandt.net_id])
	_cue(CUE_ARRIVAL)
	arrived.emit(brandt)
	return true


func captain_def() -> EnemyDef:
	if tw().captain_def != null:
		return tw().captain_def
	return load(BRANDT_PATH) as EnemyDef if ResourceLoader.exists(BRANDT_PATH) else null


## enemy.bulwark (faction-resolved) when it exists, else the Aegis placeholder.
func shield_def() -> EnemyDef:
	var b: EnemyDef = director.enemy_def_for(BULWARK_ID)
	if b != null:
		return b
	if tw().aegis_def != null:
		return tw().aegis_def
	return load(AEGIS_PATH) as EnemyDef if ResourceLoader.exists(AEGIS_PATH) else null


## Shields still in formation (alive, not broken up).
func alive_shields() -> int:
	var k: int = 0
	for s: NpcBase in shields:
		if is_instance_valid(s) and s.alive and s.has_meta(META_AEGIS):
			k += 1
	return k


static func is_aegis_unit(npc: NpcBase) -> bool:
	return npc != null and (npc.has_meta(META_AEGIS) or npc.has_meta(META_CAPTAIN))


## Server: hit amount after the Aegis resistance and the captain/shield per-hit cap (L4.9).
func modify_hit(npc: NpcBase, amount: float, info: Dictionary) -> float:
	var out: float = amount
	if in_position and resistance > 0.0 and AssaultDirector.POLICE_ROLES.has(npc.role):
		out *= 1.0 - resistance
	if is_aegis_unit(npc):
		var cap: float = tw().captain_hit_cap_frac * npc.max_health
		if int(info.get("type", Enums.DamageType.BULLET)) == Enums.DamageType.EXPLOSION:
			cap *= tw().captain_explosive_cap_mult
		out = minf(out, cap)
	if npc.has_meta(META_CAPTAIN):
		out = minf(out, maxf(npc.health - 1.0, 0.0))  # cannot be killed
	return out


## Server: Brandt leaves (reason RETREAT_HP / RETREAT_FORMATION / any). Idempotent.
func retreat(reason: StringName) -> void:
	if not active:
		return
	active = false
	in_position = false
	retreat_reason = reason
	_set_resistance(0.0)
	for s: NpcBase in shields:
		if is_instance_valid(s) and s.has_meta(META_AEGIS):
			s.remove_meta(META_AEGIS)  # PD2 phalanx breakup: the rest fight on as normal units
			s.remove_meta(META_NO_FLINCH)
	shields.clear()
	var id: int = brandt.net_id if is_instance_valid(brandt) else 0
	Log.info(&"director", "Commander Brandt retreats (%s)" % reason)
	EventBus.captain_retreated.emit(id)
	Net.replicate_event(&"captain_retreated", [id])
	retreated.emit(brandt, reason)
	if is_instance_valid(brandt):
		var b: NpcBase = brandt
		if tw().captain_despawn_s <= 0.0:
			b.queue_free()
		else:
			get_tree().create_timer(tw().captain_despawn_s, false, true).timeout.connect(
				func() -> void:
					if is_instance_valid(b):
						b.queue_free())


func _physics_process(delta: float) -> void:
	if not active or not Net.is_authority():
		return
	if not is_instance_valid(brandt) or not brandt.alive:
		retreat(RETREAT_HP)
		return
	_t_active += delta
	if not in_position:
		if _t_active >= tw().captain_settle_s:
			in_position = true
			_step_t = 0.0
			_set_resistance(tw().aegis_resist_base)
			_cue(CUE_PULSE)
	else:
		_step_t += delta
		while _step_t >= tw().aegis_resist_step_s and tw().aegis_resist_step_s > 0.0:
			_step_t -= tw().aegis_resist_step_s
			_set_resistance(minf(resistance + tw().aegis_resist_step, tw().aegis_resist_max))
			_cue(CUE_PULSE)
	_check_retreat()


func _check_retreat() -> void:
	if not active:
		return
	if is_instance_valid(brandt) and brandt.health <= tw().captain_retreat_hp_frac * brandt.max_health:
		retreat(RETREAT_HP)
	elif alive_shields() <= tw().captain_retreat_shields:
		retreat(RETREAT_FORMATION)


func _set_resistance(r: float) -> void:
	if is_equal_approx(r, resistance):
		resistance = r
		return
	resistance = r
	resistance_changed.emit(r)


func _cue(cue_id: StringName) -> void:
	var pos: Vector3 = brandt.global_position if is_instance_valid(brandt) and brandt.is_inside_tree() else Vector3.ZERO
	var id: int = brandt.net_id if is_instance_valid(brandt) else 0
	EventBus.audio_cue_requested.emit(cue_id, pos, id)
	Net.replicate_event(&"audio_cue_requested", [cue_id, pos, id])


func _on_brandt_damaged(_info: Dictionary, _attacker: int) -> void:
	_check_retreat()


func _on_shield_died() -> void:
	_check_retreat()
