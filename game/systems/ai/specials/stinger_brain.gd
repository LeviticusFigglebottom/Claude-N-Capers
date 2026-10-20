## Stinger brain (A3-01a, L4.4; PD2 Taser). Owner: ENV A. Server only. Child `Brain` of npc_stinger.tscn
## (siblings: Motor, Gunner: it shoots normally while not winding up / tasing).
## Behaviour (numbers in SpecialTweak, ◇):
## - targets the nearest standing crew member, preferring one no other Stinger is on (pairs retarget);
## - within stinger_tase_range_m with LOS and off cooldown: audible windup (cue.stinger_windup,
##   stinger_windup_s), then the tase: CrewHealth.incapacitate(TASED) (L2.8, no down); the victim's
##   CrewWeapons.involuntary_fire (spread x3, 15 deg up): it fires at max RPM and auto-reloads;
##   the victim cannot move or interact (CrewController: TASED is not mobile). cue.stinger_arc repeats
##   every stinger_arc_interval_s; `ArcBeam` (blue arc VFX node, C) is stretched to the victim;
## - the tase breaks (victim back to NORMAL via CrewHealth.end_tase(): NOT a revive, no crew_revived,
##   D-049) when the Stinger dies, is stunned, loses LOS, or the victim leaves stinger_break_range_m;
## - every end of the beam (any reason, incl. helpless / freed) emits crew_tase_ended(slot) [R] once:
##   the end fact for the cue.stinger_arc loop and the HUD (a real revive still emits crew_revived);
## - long tase: after stinger_helpless_after_s the beam ends and the victim goes DOWNED (D-145, PD2; was: stayed TASED,
##   L2.8) until a teammate revives them; the Stinger then retargets;
## - defense.shockproof (PARAMS): `backfire_chance` -> the tase backfires (Stinger knocked back, no
##   tase); `can_interact_counter` + `counter_window` s -> the victim pressing interact within the window
##   breaks the tase and knocks the Stinger back. `tase_shorten` is not used yet (no PD2 equivalent
##   defined; the shipped data is 0.0).
class_name StingerBrain
extends SpecialBrain

## Arc origin ahead of the HandR/Socket grip (m): about the taser muzzle.
const ARC_MUZZLE_M: float = 0.3
## D-145: crew meta, heist time (s) until which no Stinger may tase them again.
const IMMUNE_META: StringName = &"stinger_immune_until"

## Why the last tase ended: &"killed", &"stunned", &"los", &"range", &"helpless", &"counter",
## &"backfire", &"freed" (revived by a teammate), &"aborted" (windup broken).
var last_break_reason: StringName = &""
var tases_started: int = 0
var tase_victim: CrewController = null
var tase_time: float = 0.0
var tase_cooldown_left: float = 0.0

var _windup_left: float = 0.0
var _arc_left: float = 0.0
var _counter_window: float = 0.0
var _target_visible: bool = false
var _arc_beam: Node3D = null
var _tase_slot: int = -1


func _on_started() -> void:
	_arc_beam = _npc.get_node_or_null("ArcBeam") as Node3D
	if _arc_beam != null:
		_arc_beam.visible = false


func _tick_active(delta: float) -> void:
	if tase_cooldown_left > 0.0:
		tase_cooldown_left = maxf(tase_cooldown_left - delta, 0.0)
	match mode:
		&"windup":
			_tick_windup(delta)
		&"tase":
			_tick_tase(delta)
		_:
			_tick_pursue(delta)
	var t: CrewController = combat_target as CrewController
	wants_to_fire = (mode == &"approach" or mode == &"hold") and t != null and _target_visible


func _on_stunned_tick(_delta: float) -> void:
	if mode == &"tase":
		_end_tase(&"stunned", true)
	elif mode == &"windup":
		_abort_windup()


# --- Pursuit ---------------------------------------------------------------------------------------

## D-145: the re-tase cooldown on this heist's difficulty (stinger_tase_cooldown_by_difficulty, else the flat value).
func _cooldown_s() -> float:
	return _by_difficulty(tweak.stinger_tase_cooldown_by_difficulty, tweak.stinger_tase_cooldown_s)


## D-145: `c` was tased recently enough that no Stinger may tase them again yet.
func _immune(c: CrewController) -> bool:
	return _runtime != null and c.has_meta(IMMUNE_META) and _runtime.heist_time_s < float(c.get_meta(IMMUNE_META))


func _by_difficulty(values: PackedFloat32Array, fallback: float) -> float:
	var d: int = _runtime.difficulty if _runtime != null else -1
	return values[d] if d >= 0 and d < values.size() else fallback

func _unclaimed(c: CrewController) -> bool:
	if not c.has_meta(CLAIM_META):
		return true
	var owner_id: int = int(c.get_meta(CLAIM_META))
	if owner_id == _npc.get_instance_id():
		return true
	var o: NpcBase = instance_from_id(owner_id) as NpcBase
	return o == null or not is_instance_valid(o) or not o.alive


func _pick_target() -> void:
	var r: Dictionary = nearest_standing(_unclaimed)
	if r["crew"] == null:
		r = nearest_standing()
	combat_target = r["crew"]
	_target_visible = bool(r["visible"])


func _tick_pursue(delta: float) -> void:
	_retarget_left -= delta
	if _retarget_left <= 0.0 or combat_target == null or not is_instance_valid(combat_target) \
			or not standing_crew().has(combat_target):
		_retarget_left = roll(tweak.retarget_s)
		_pick_target()
	var t: CrewController = combat_target as CrewController
	if t == null:
		_target_visible = false
		_motor.stop()
		mode = &"idle"
		anim_hint = &"idle_alert"
		return
	_target_visible = can_see(t)
	var d: float = flat_dist_to(t)
	if tase_cooldown_left <= 0.0 and _target_visible and d <= tweak.stinger_tase_range_m and _unclaimed(t) \
			and not _immune(t):
		_begin_windup(t)
		return
	if not _target_visible or d > tweak.stinger_tase_range_m * tweak.stinger_hold_frac:
		move_to(t.global_position, &"approach")
	else:
		hold(t.global_position)


# --- Windup + tase ------------------------------------------------------------------------------------

func _begin_windup(t: CrewController) -> void:
	tase_victim = t
	t.set_meta(CLAIM_META, _npc.get_instance_id())
	mode = &"windup"
	anim_hint = &"aim"
	_windup_left = tweak.stinger_windup_s
	_motor.stop()
	_motor.face_point(t.global_position)
	cue(&"cue.stinger_windup")


func _tick_windup(delta: float) -> void:
	var v: CrewController = tase_victim
	if v == null or not is_instance_valid(v) or not standing_crew().has(v) or not can_see(v) \
			or flat_dist_to(v) > tweak.stinger_tase_range_m:
		_abort_windup()
		return
	_motor.face_point(v.global_position)
	_windup_left -= delta
	if _windup_left <= 0.0:
		_start_tase(v)


func _abort_windup() -> void:
	last_break_reason = &"aborted"
	_release_claim()
	tase_victim = null
	mode = &"approach"


func _start_tase(v: CrewController) -> void:
	var sp: Dictionary = Modifiers.params(v.slot, &"defense.shockproof")
	if chance(float(sp.get("backfire_chance", 0.0))):
		_release_claim()
		tase_victim = null
		_knockback(&"backfire")
		return
	if v.health == null or not v.health.incapacitate(Enums.CrewState.TASED, _npc.net_id):
		_abort_windup()
		return
	tases_started += 1
	_tase_slot = v.slot
	tase_time = 0.0
	_arc_left = 0.0
	_counter_window = float(sp.get("counter_window", 0.0)) if bool(sp.get("can_interact_counter", false)) else 0.0
	mode = &"tase"
	anim_hint = &"aim"
	if v.weapons != null:
		v.weapons.involuntary_spread_mult = tweak.stinger_spread_mult
		v.weapons.involuntary_pitch_up_deg = tweak.stinger_pitch_up_deg
		v.weapons.involuntary_fire = true
	if _arc_beam != null:
		_arc_beam.visible = true


## Where the arc leaves the Stinger (presentation only): ahead of the character's weapon hand
## (`HandR/Socket`, -Z = muzzle, characters.md v1.2), else chest height on the capsule placeholder.
func arc_origin() -> Vector3:
	var socket: Node3D = AnimDriver.socket_of(_npc, "HandR")
	if socket != null and socket.is_inside_tree():
		return socket.global_transform * Vector3(0.0, 0.0, -ARC_MUZZLE_M)
	return _npc.eye_position() + Vector3(0.0, -0.3, 0.0)


func _tick_tase(delta: float) -> void:
	var v: CrewController = tase_victim
	if v == null or not is_instance_valid(v) or v.crew_state != Enums.CrewState.TASED:
		_end_tase(&"freed", false)
		return
	tase_time += delta
	_motor.face_point(v.global_position)
	_arc_left -= delta
	if _arc_left <= 0.0:
		_arc_left = tweak.stinger_arc_interval_s
		cue(&"cue.stinger_arc", v.global_position)
	aim_beam(_arc_beam, arc_origin(), CombatSystem.target_center(v))
	if _counter_window > 0.0 and tase_time <= _counter_window and v.intent != null and v.intent.interact:
		_end_tase(&"counter", true)
		_knockback(&"counter")
		return
	if not can_see(v):
		_end_tase(&"los", true)
	elif flat_dist_to(v) > tweak.stinger_break_range_m:
		_end_tase(&"range", true)
	elif tase_time >= tweak.stinger_helpless_after_s:
		var victim: CrewController = tase_victim
		_end_tase(&"helpless", false)
		if victim != null and is_instance_valid(victim) and victim.health != null:
			victim.health.tase_expired()  # D-145 (PD2): a tase that runs out downs the player; bleed-out decides custody


## End the beam. `free_victim`: the victim gets up (TASED -> NORMAL via CrewHealth.end_tase(), no
## crew_revived). Always emits crew_tase_ended(victim slot) [R] (D-049).
func _end_tase(reason: StringName, free_victim: bool) -> void:
	last_break_reason = reason
	var v: CrewController = tase_victim
	var victim_slot: int = _tase_slot
	if v != null and is_instance_valid(v):
		victim_slot = v.slot
		if v.weapons != null:
			v.weapons.involuntary_fire = false
		if free_victim and v.crew_state == Enums.CrewState.TASED and v.health != null:
			v.health.end_tase()
	_release_claim()
	_tase_slot = -1
	if v != null and is_instance_valid(v) and _runtime != null:
		var immune: float = _by_difficulty(tweak.stinger_victim_immune_s_by_difficulty, 0.0)
		if immune > 0.0:
			v.set_meta(IMMUNE_META, _runtime.heist_time_s + immune)  # D-145: no Stinger re-tases them for a while
	if victim_slot >= 0:
		EventBus.crew_tase_ended.emit(victim_slot)
		Net.replicate_event(&"crew_tase_ended", [victim_slot])
	tase_victim = null
	tase_cooldown_left = _cooldown_s()
	if _arc_beam != null:
		_arc_beam.visible = false
	mode = &"approach"
	_retarget_left = 0.0


func _knockback(reason: StringName) -> void:
	last_break_reason = reason
	tase_cooldown_left = _cooldown_s()
	mode = &"approach"
	anim_hint = &"hit_react"
	_npc.stun(tweak.stinger_knockback_s)


func _release_claim() -> void:
	var v: CrewController = tase_victim
	if v != null and is_instance_valid(v) and v.has_meta(CLAIM_META) \
			and int(v.get_meta(CLAIM_META)) == _npc.get_instance_id():
		v.remove_meta(CLAIM_META)


func _on_npc_died() -> void:
	if mode == &"tase":
		_end_tase(&"killed", true)
	elif mode == &"windup":
		_abort_windup()


func _exit_tree() -> void:
	if mode == &"tase" and tase_victim != null and is_instance_valid(tase_victim) and tase_victim.weapons != null:
		tase_victim.weapons.involuntary_fire = false
	_release_claim()
	if mode == &"tase" and _tase_slot >= 0 and Net.is_authority():
		# Despawned mid-tase: the beam ends (loop end fact); the victim stays TASED until revived.
		EventBus.crew_tase_ended.emit(_tase_slot)
		Net.replicate_event(&"crew_tase_ended", [_tase_slot])
	_tase_slot = -1
