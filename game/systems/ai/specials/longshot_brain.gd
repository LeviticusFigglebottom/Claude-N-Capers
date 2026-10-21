## Longshot brain (A3-01a, L4.7; PD2 Sniper). Owner: ENV A. Server only. Child `Brain` of npc_longshot.tscn.
## - Perch only: a Longshot lives on a SNIPER_PERCH TacticalPoint. SpecialSpawner.spawn_special picks a
##   free perch; one spawned anywhere else (e.g. a director spawn point) is moved to the nearest free
##   perch at start, and stays dormant (never fires) when the map has none. It never leaves the perch.
## - Aim lock: a visible red laser (`LaserBeam`, stretched from the `LaserOrigin` marker; C's shader)
##   tracks the target for longshot_aim_lock_s (◇ 1.2 s), then the shot: EnemyDef.damage[difficulty]
##   (100-240), x longshot_falloff_mult beyond longshot_falloff_m (30 m) except on the top difficulty,
##   with `bypass_armor_gate` (L2.2: the overflow past armor reaches health). cue.longshot_report at
##   the muzzle; weapon_fired; a gunshot noise. LOS lost for longshot_los_grace_s drops the lock.
## - `laser_active` / `laser_point` are the replicable presentation state (laser visible to all players;
##   NPC state sync is P3 net work, the server drives the beam node directly).
class_name LongshotBrain
extends SpecialBrain

var perch: TacticalPoint = null
var laser_active: bool = false
var laser_point: Vector3 = Vector3.ZERO
## Seconds of aim lock accumulated on the current target.
var aim_time: float = 0.0
var shots_fired: int = 0

var _fire_cooldown: float = 0.0
var _los_lost: float = 0.0
var _laser_origin: Node3D = null
var _laser_beam: Node3D = null


func _on_started() -> void:
	_laser_beam = _npc.get_node_or_null("LaserBeam") as Node3D
	_set_laser(false)
	perch = SpecialSpawner.perch_at(_runtime, _npc.global_position, tweak.longshot_perch_snap_m, _npc)
	if perch == null:
		perch = SpecialSpawner.free_perch(_runtime, _npc.global_position, _npc)
		if perch != null:
			_npc.global_position = perch.global_position
	if perch != null:
		perch.set_meta(CLAIM_META, _npc.get_instance_id())
	else:
		Log.warn(&"ai", "Longshot %d has no SNIPER_PERCH: dormant" % _npc.net_id)
	_motor.stop()


func is_perched() -> bool:
	return perch != null


func _tick_active(delta: float) -> void:
	_motor.stop()
	if perch == null:
		mode = &"dormant"
		return
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	_retarget_left -= delta
	var t: CrewController = combat_target as CrewController
	if _retarget_left <= 0.0 or t == null or not is_instance_valid(t) or not standing_crew().has(t):
		_retarget_left = roll(tweak.retarget_s)
		var nt: CrewController = _pick_target()
		if nt != t:
			aim_time = 0.0
		t = nt
		combat_target = nt
	if t == null:
		mode = &"idle"
		anim_hint = &"idle_alert"
		aim_time = 0.0
		_set_laser(false)
		return
	if not can_see(t) or _npc.eye_position().distance_to(t.eye_position()) > tweak.longshot_range_m:
		_los_lost += delta
		if _los_lost >= tweak.longshot_los_grace_s:
			aim_time = 0.0
			combat_target = null
			_set_laser(false)
			mode = &"search"
		return
	_los_lost = 0.0
	mode = &"aim"
	anim_hint = &"aim_rifle"
	_motor.face_point(t.global_position)
	_set_laser(true)
	laser_point = CombatSystem.target_center(t)
	aim_beam(_laser_beam, _origin(), laser_point)
	if _fire_cooldown > 0.0:
		return
	aim_time += delta
	if aim_time >= _by_difficulty(tweak.longshot_aim_lock_s_by_difficulty, tweak.longshot_aim_lock_s):
		_fire(t)


func _pick_target() -> CrewController:
	var best: CrewController = null
	var best_d: float = INF
	for c: CrewController in standing_crew():
		var d: float = _npc.eye_position().distance_to(c.eye_position())
		if d < best_d and d <= tweak.longshot_range_m and can_see(c):
			best_d = d
			best = c
	return best


## L4.7 shot damage at `distance` (m) for this unit's difficulty.
func shot_damage(distance: float) -> float:
	var def: EnemyDef = _npc.enemy_def
	var dmg: float = def.damage[clampi(_npc.difficulty, 0, def.damage.size() - 1)] if def != null and def.damage.size() > 0 \
		else CombatTweak.data().npc_fallback_damage
	if distance > tweak.longshot_falloff_m and _npc.difficulty != Enums.Difficulty.CATACLYSM:
		dmg *= tweak.longshot_falloff_mult
	return dmg


func _fire(t: CrewController) -> void:
	aim_time = 0.0
	_fire_cooldown = _by_difficulty(tweak.longshot_fire_interval_s_by_difficulty, tweak.longshot_fire_interval_s)
	shots_fired += 1
	# DET: gameplay (event, noise, falloff distance) from the body's eye, not the LaserOrigin marker: that rides the
	# animated HandR socket, which the AnimationPlayer poses per render frame (a frame-timing-dependent position).
	var from: Vector3 = _npc.eye_position()
	var aim: Vector3 = CombatSystem.target_center(t)
	var weapon_id: StringName = _npc.enemy_def.weapon if _npc.enemy_def != null else &""
	EventBus.weapon_fired.emit(_npc.net_id, weapon_id, false, from)
	cue(&"cue.longshot_report", from)
	if _runtime != null:
		_runtime.make_noise(from, Tweak.stealth().gunshot_npc_radius_m, &"gunshot", _npc.net_id)
	ShotFx.npc_shot(_npc, _origin(), aim, true, t)  # PO-8: shot_fx here + relayed (impact_fx.md); the laser's muzzle
	var info: Dictionary = Damage.info(shot_damage(from.distance_to(aim)), Enums.DamageType.BULLET,
		Enums.HitZone.BODY, weapon_id, aim, (aim - from).normalized(), _npc.net_id)
	info["bypass_armor_gate"] = true  # L2.2 / L4.7: snipers ignore armor gating
	t.take_hit(info, _npc.net_id)


func _origin() -> Vector3:
	if _laser_origin == null or not is_instance_valid(_laser_origin):
		_laser_origin = _npc.find_child("LaserOrigin", true, false) as Node3D
	if _laser_origin != null and _laser_origin.is_inside_tree():
		return _laser_origin.global_position
	return _npc.eye_position()


func _set_laser(on: bool) -> void:
	laser_active = on
	if _laser_beam != null:
		_laser_beam.visible = on


func _on_npc_died() -> void:
	_set_laser(false)
	if perch != null and is_instance_valid(perch) and perch.has_meta(CLAIM_META) \
			and int(perch.get_meta(CLAIM_META)) == _npc.get_instance_id():
		perch.remove_meta(CLAIM_META)


func _on_stunned_tick(_delta: float) -> void:
	aim_time = 0.0
	_set_laser(false)


## D-145: the per-difficulty value of `values` (Routine..Cataclysm), else `fallback`.
func _by_difficulty(values: PackedFloat32Array, fallback: float) -> float:
	var d: int = _runtime.difficulty if _runtime != null else -1
	return values[d] if d >= 0 and d < values.size() else fallback
