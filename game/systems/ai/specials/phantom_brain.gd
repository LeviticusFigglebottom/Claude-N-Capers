## Phantom brain (A3-01a, L4.3; PD2 Cloaker). Owner: ENV A. Server only. Child `Brain` of npc_phantom.tscn.
## Telegraphs (L4 preamble): cue.phantom_hum every phantom_hum_interval_s while active (3D, 25 m in
## C's cue def); on a charge cue.phantom_charge plus the `Goggles` emission ramping up (green glow).
## Behaviour (numbers in SpecialTweak, ◇):
## - flank: on activation it may first run to a FLANK TacticalPoint near the target; its NavAgent
##   also walks the `vent` nav layer (npc_phantom.tscn navigation_layers = walkable | vent).
## - charge: target within phantom_charge_range_m, in LOS, kick off cooldown -> windup
##   (phantom_windup_s): the charge line is COMMITTED toward the target's position at windup start,
##   then a sprint along it. The kick lands only if the victim is within phantom_kick_range_m AND
##   within phantom_dodge_lateral_m of the committed line (a sidestep dodges). Hit or miss, the kick
##   goes on phantom_kick_cooldown_s (~10 s).
## - kick: CrewHealth.incapacitate(CLOAKER_DOWNED) (D-145, PD2: a normal down, counted); may camp the body.
## - never kicks the last player standing (incl. a solo player with no AI): it keeps a standoff.
## - "play dead": phantom_play_dead_chance per non-lethal hit to drop, getting up after a while.
## - ECM feedback immune: EnemyDef.params.ecm_feedback_immune (EcmSystem._immune).
## - defense.cloaker_counter (Counterstrike aced): the victim holding melee (intent.melee) when the
##   kick lands knocks the Phantom down (stun phantom_counter_knockdown_s) instead. Holding melee is
##   CrewMelee's charge (L3.9), so the held intent is the charging check.
## Not yet: the post-kick beating and smoke drop (PD2 flavour; no gameplay effect beyond the takedown).
class_name PhantomBrain
extends SpecialBrain

## Kick results (tests / voice): &"hit", &"dodged", &"countered", &"aborted".
var last_kick_result: StringName = &""
var kicks_landed: int = 0
var kick_cooldown_left: float = 0.0
var goggles_glowing: bool = false
## Committed charge line (flat), valid during windup / charge.
var charge_origin: Vector3 = Vector3.ZERO
var charge_dir: Vector3 = Vector3.ZERO
var victim: CrewController = null

var _hum_left: float = 0.0
var _windup_left: float = 0.0
var _charge_left: float = 0.0
var _camp_left: float = 0.0
var _play_dead_left: float = 0.0
var _play_dead_count: int = 0
var _flank_point: Node3D = null
var _flank_left: float = 0.0
var _goggles: GeometryInstance3D = null
var _visual_rot: Vector3 = Vector3.ZERO
var _visual_pos: Vector3 = Vector3.ZERO


func _on_started() -> void:
	_npc.damaged.connect(_on_damaged)
	_set_goggles(false)


func _on_activate() -> void:
	_hum_left = 0.0
	_pick_target()
	if combat_target != null and chance(tweak.phantom_flank_chance):
		_flank_point = find_flank_point(combat_target as Node3D, tweak.phantom_flank_max_from_target_m)
		_flank_left = tweak.phantom_flank_timeout_s


func _tick_active(delta: float) -> void:
	if kick_cooldown_left > 0.0:
		kick_cooldown_left = maxf(kick_cooldown_left - delta, 0.0)
	if mode == &"play_dead":
		_play_dead_left -= delta
		if _play_dead_left <= 0.0:
			_get_up()
		return
	_hum_left -= delta
	if _hum_left <= 0.0:
		_hum_left = tweak.phantom_hum_interval_s
		cue(&"cue.phantom_hum")
	match mode:
		&"windup":
			_tick_windup(delta)
		&"charge":
			_tick_charge(delta)
		&"camp":
			_tick_camp(delta)
		_:
			_tick_pursue(delta)


func _on_stunned_tick(_delta: float) -> void:
	if mode == &"windup" or mode == &"charge":
		_end_charge(&"aborted")


# --- Pursuit -------------------------------------------------------------------------------------

func _pick_target() -> void:
	var r: Dictionary = nearest_standing()
	combat_target = r["crew"]


## L4.3: never kicks the last player standing (a solo player without AI is always the last).
func can_kick(c: CrewController) -> bool:
	if c == null or not is_instance_valid(c):
		return false
	if c.crew_state != Enums.CrewState.NORMAL and c.crew_state != Enums.CrewState.SWAN_SONG:
		return false
	return standing_crew().size() > 1


func _tick_pursue(delta: float) -> void:
	_retarget_left -= delta
	if _retarget_left <= 0.0 or combat_target == null or not is_instance_valid(combat_target) \
			or not standing_crew().has(combat_target):
		_retarget_left = roll(tweak.retarget_s)
		_pick_target()
	var t: CrewController = combat_target as CrewController
	if t == null:
		_motor.stop()
		mode = &"idle"
		anim_hint = &"idle_alert"
		return
	if _flank_point != null:
		_flank_left -= delta
		if not is_instance_valid(_flank_point) or _flank_left <= 0.0 \
				or flat_dist_to(_flank_point) <= tweak.arrive_m:
			_flank_point = null
		else:
			move_to(_flank_point.global_position, &"flank")
			return
	var d: float = flat_dist_to(t)
	var kickable: bool = can_kick(t)
	if kickable and kick_cooldown_left <= 0.0 and d <= tweak.phantom_charge_range_m and can_see(t):
		_begin_windup(t)
		return
	if not kickable:
		if d > tweak.phantom_standoff_m + tweak.arrive_m:
			move_to(t.global_position, &"standoff")
		else:
			hold(t.global_position, &"standoff")
		return
	move_to(t.global_position, &"approach")


# --- Charge ---------------------------------------------------------------------------------------

func _begin_windup(t: CrewController) -> void:
	victim = t
	mode = &"windup"
	anim_hint = &"kick_charge"
	_windup_left = tweak.phantom_windup_s
	charge_origin = _flat(_npc.global_position)
	var to: Vector3 = _flat(t.global_position) - charge_origin
	charge_dir = to.normalized() if to.length() > 0.01 else _npc.look_forward()
	_charge_left = to.length()  # reused as the committed distance until the sprint starts
	_motor.stop()
	_motor.face(charge_dir)
	_set_goggles(true)
	cue(&"cue.phantom_charge")


func _tick_windup(delta: float) -> void:
	if victim == null or not is_instance_valid(victim) or not can_kick(victim):
		_end_charge(&"aborted")
		return
	_windup_left -= delta
	if _windup_left > 0.0:
		return
	mode = &"charge"
	anim_hint = &"sprint"
	var length: float = _charge_left + tweak.phantom_charge_overshoot_m
	var end: Vector3 = charge_origin + charge_dir * length
	end.y = _npc.global_position.y
	_charge_left = tweak.phantom_charge_timeout_s
	_motor.go_to(end, tweak.phantom_charge_speed)


func _tick_charge(delta: float) -> void:
	_charge_left -= delta
	if victim == null or not is_instance_valid(victim) or not can_kick(victim):
		_end_charge(&"aborted")
		return
	var dist: float = flat_dist_to(victim)
	if dist <= tweak.phantom_kick_range_m and lateral_offset(victim) <= tweak.phantom_dodge_lateral_m:
		_kick()
		return
	if _motor.arrived or _charge_left <= 0.0:
		_end_charge(&"dodged")


## Flat distance of `c` from the committed charge line.
func lateral_offset(c: Node3D) -> float:
	var l: Vector3 = _flat(c.global_position) - charge_origin
	return (l - charge_dir * l.dot(charge_dir)).length()


func _kick() -> void:
	var v: CrewController = victim
	if Modifiers.flag(v.slot, &"defense.cloaker_counter") and v.intent != null and v.intent.melee:
		_end_charge(&"countered")
		_npc.stun(tweak.phantom_counter_knockdown_s)
		mode = &"knocked_down"
		anim_hint = &"hit_react"
		return
	var ok: bool = v.health != null and v.health.incapacitate(Enums.CrewState.CLOAKER_DOWNED, _npc.net_id)
	if not ok:
		_end_charge(&"aborted")
		return
	kicks_landed += 1
	_end_charge(&"hit")
	anim_hint = &"kick_hit"
	if chance(tweak.phantom_camp_chance):
		mode = &"camp"
		_camp_left = tweak.phantom_camp_s
		victim = v


func _end_charge(result: StringName) -> void:
	last_kick_result = result
	if result != &"aborted":
		kick_cooldown_left = tweak.phantom_kick_cooldown_s
	_set_goggles(false)
	_motor.stop()
	mode = &"approach"
	victim = null
	_retarget_left = 0.0


func _tick_camp(delta: float) -> void:
	_camp_left -= delta
	if _camp_left <= 0.0 or victim == null or not is_instance_valid(victim) \
			or victim.crew_state != Enums.CrewState.CLOAKER_DOWNED:
		victim = null
		mode = &"approach"
		return
	if flat_dist_to(victim) > tweak.phantom_kick_range_m:
		move_to(victim.global_position, &"camp")
	else:
		hold(victim.global_position, &"camp")
		anim_hint = &"idle_alert"


# --- Play dead ---------------------------------------------------------------------------------------

func _on_damaged(info: Dictionary, _attacker: int) -> void:
	if not _active or not _npc.alive or bool(info.get("killed", false)) or mode == &"play_dead":
		return
	if _play_dead_count >= tweak.phantom_play_dead_max or not chance(tweak.phantom_play_dead_chance):
		return
	start_play_dead()


## Drop "dead" for a rolled time (still alive and hittable), then get up.
func start_play_dead() -> void:
	if mode == &"windup" or mode == &"charge":
		_end_charge(&"aborted")
	_play_dead_count += 1
	_play_dead_left = roll(tweak.phantom_play_dead_s)
	mode = &"play_dead"
	anim_hint = &"lie_down"
	_motor.stop()
	if _npc.visual_root != null:
		_visual_rot = _npc.visual_root.rotation
		_visual_pos = _npc.visual_root.position
		_npc.visual_root.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		_npc.visual_root.position = Vector3(0.0, 0.25, 0.0)


func is_playing_dead() -> bool:
	return mode == &"play_dead"


func _get_up() -> void:
	mode = &"approach"
	anim_hint = &"idle_alert"
	_retarget_left = 0.0
	if _npc.visual_root != null:
		_npc.visual_root.rotation = _visual_rot
		_npc.visual_root.position = _visual_pos


func _on_npc_died() -> void:
	_set_goggles(false)


# --- Goggles (characters.md: Phantom `Goggles` with emission) ---------------------------------------

func _set_goggles(charging: bool) -> void:
	goggles_glowing = charging
	if _goggles == null or not is_instance_valid(_goggles):
		_goggles = _npc.find_child("Goggles", true, false) as GeometryInstance3D
		if _goggles == null:
			return
		var m: BaseMaterial3D = _goggles.material_override as BaseMaterial3D
		if m != null:
			_goggles.material_override = m.duplicate()  # per-instance glow
	var energy: float = tweak.phantom_goggle_energy_charge if charging else tweak.phantom_goggle_energy_idle
	var bm: BaseMaterial3D = _goggles.material_override as BaseMaterial3D
	if bm != null:
		bm.emission_enabled = true
		bm.emission_energy_multiplier = energy
	elif _goggles.material_override is ShaderMaterial:
		_goggles.set_instance_shader_parameter(&"glow", 1.0 if charging else 0.0)
