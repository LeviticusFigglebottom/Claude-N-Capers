## PO6-17: the turret van's roof turret (PD2 SWAT van turret). Owner: ENV A. Child `Turret` of an
## AssaultTurretVan; visuals on every peer (ENV C `prop_sentry_turret`: Model/Yaw turns about Y, Model/Yaw/Pitch
## tilts about X, Model/Yaw/Pitch/Muzzle -Z = fire), behaviour on the server only.
## Damage (docs/contracts/damage.md single hit path, this node is the target via its Hitboxes):
## - BODY hits (front shield, receiver, base) go to armor_hp first, then health; WEAKPOINT (the rear ammo box)
##   skips the armor and takes x weakspot_mult; explosions take x explosive_mult. health <= 0 = destroyed.
## - every hit emits damage_applied [R] with the van's net id as victim.
## Fire (server): nearest standing crew member in range with LOS from the muzzle, turned to at turn_deg_s /
## pitch_deg_s, aim_delay_s before the first shot, then bursts (burst_s firing every fire_interval_s,
## burst_pause_s pause). Hit chance = CombatTweak.npc_hit_chance(distance, difficulty) x accuracy_mult; a hit is
## one crew.take_hit of damage[difficulty]. Suppression: after LOS is lost it keeps firing at the last seen point
## for suppress_s (PD2 turrets hose the cover the crew ducked behind).
class_name AssaultTurret
extends Node3D

signal destroyed_changed(destroyed: bool)

const LAYER_HITBOXES: int = 1 << 4

var van: AssaultTurretVan = null
var difficulty: int = 0
var armor_hp: float = 0.0
var health: float = 0.0
var max_health: float = 0.0
var max_armor: float = 0.0
var destroyed: bool = false
## Server: shooting allowed (the van deployed it).
var armed: bool = false
var yaw: float = 0.0
var pitch: float = 0.0
var shots_fired: int = 0
var hits_landed: int = 0
var target: CrewController = null

var yaw_node: Node3D = null
var pitch_node: Node3D = null
var muzzle: Node3D = null
var hitboxes: Array[Hitbox] = []

var _cool: float = 0.0
var _aim_wait: float = 0.0
var _burst_left: float = 0.0
var _pause_left: float = 0.0
var _retarget_left: float = 0.0
var _last_seen: Vector3 = Vector3.INF
var _suppress_left: float = 0.0


func setup(p_van: AssaultTurretVan, scene_rel: String) -> void:
	van = p_van
	difficulty = int(van.params.get("difficulty", 0))
	max_armor = van.p_float("armor_hp", 800.0, difficulty)
	max_health = van.p_float("health", 2000.0, difficulty)
	armor_hp = max_armor
	health = max_health
	var model: Node3D = AssaultEventEntity.prop(scene_rel)
	if model == null:
		model = _placeholder()
	model.name = "Prop"
	add_child(model)
	yaw_node = AssaultEventEntity.find_named(model, "Yaw")
	pitch_node = AssaultEventEntity.find_named(model, "Pitch")
	muzzle = AssaultEventEntity.find_named(model, "Muzzle")
	_add_hitbox(self, "HitBase", Vector3(0.7, 0.8, 0.7), Vector3(0, 0.4, 0), Enums.HitZone.BODY)
	if pitch_node != null:
		_add_hitbox(pitch_node, "HitBody", Vector3(0.75, 0.55, 1.0), Vector3(0, 0, -0.25), Enums.HitZone.BODY)
		_add_hitbox(pitch_node, "HitWeakSpot", Vector3(0.4, 0.4, 0.32), Vector3(0, 0, 0.42), Enums.HitZone.WEAKPOINT)


## Same node names / axes as C's prop_sentry_turret.
static func _placeholder() -> Node3D:
	var root: Node3D = Node3D.new()
	var model: Node3D = Node3D.new()
	model.name = "Model"
	root.add_child(model)
	var base: MeshInstance3D = AssaultEventEntity.cylinder("Base", 0.28, 0.75, Color(0.17, 0.18, 0.2), Vector3(0, 0.375, 0))
	model.add_child(base)
	var y: Node3D = AssaultEventEntity.marker("Yaw", Vector3(0, 0.75, 0))
	model.add_child(y)
	y.add_child(AssaultEventEntity.box("YawMesh", Vector3(0.6, 0.2, 0.6), Color(0.12, 0.16, 0.27)))
	var p: Node3D = AssaultEventEntity.marker("Pitch", Vector3(0, 0.24, 0))
	y.add_child(p)
	var pm: Node3D = AssaultEventEntity.marker("PitchMesh", Vector3.ZERO)
	p.add_child(pm)
	pm.add_child(AssaultEventEntity.box("Receiver", Vector3(0.36, 0.32, 0.7), Color(0.2, 0.21, 0.23), Vector3(0, 0, -0.1)))
	pm.add_child(AssaultEventEntity.box("Shield", Vector3(0.8, 0.5, 0.06), Color(0.84, 0.89, 0.29), Vector3(0, 0.02, -0.45)))
	pm.add_child(AssaultEventEntity.box("AmmoBox", Vector3(0.34, 0.3, 0.26), Color(0.55, 0.12, 0.1), Vector3(0, 0, 0.42)))
	var barrel: MeshInstance3D = AssaultEventEntity.cylinder("Barrel", 0.045, 0.6, Color(0.08, 0.08, 0.08), Vector3(0, 0, -0.6))
	barrel.rotation.x = PI * 0.5
	pm.add_child(barrel)
	p.add_child(AssaultEventEntity.marker("Muzzle", Vector3(0, 0, -0.89)))
	return root


func _add_hitbox(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, zone: Enums.HitZone) -> void:
	var hb: Hitbox = Hitbox.new()
	hb.name = node_name
	hb.hit_zone = zone
	hb.target = self
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	hb.add_child(cs)
	hb.position = pos
	parent.add_child(hb)
	hitboxes.append(hb)


func muzzle_position() -> Vector3:
	if muzzle != null and muzzle.is_inside_tree():
		return muzzle.global_position
	return global_position + Vector3(0, 1.0, 0)


func set_pose(p_yaw: float, p_pitch: float) -> void:
	yaw = p_yaw
	pitch = p_pitch
	if yaw_node != null:
		yaw_node.rotation.y = yaw
	if pitch_node != null:
		pitch_node.rotation.x = pitch


func set_destroyed(on: bool) -> void:
	if destroyed == on:
		return
	destroyed = on
	for hb: Hitbox in hitboxes:
		hb.set_active(not on)
	if on:
		set_pose(yaw, deg_to_rad(-28.0))  # the dead gun droops
		_tint_dead(self)
	destroyed_changed.emit(on)


static func _tint_dead(n: Node) -> void:
	var mi: MeshInstance3D = n as MeshInstance3D
	if mi != null:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.07, 0.07, 0.07)
		mat.roughness = 1.0
		mi.material_override = mat
	for c: Node in n.get_children():
		_tint_dead(c)


# --- Damage (damage.md) ----------------------------------------------------------------------

func take_hit(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	var out: Dictionary = CombatSystem.ensure_info_v11(info.duplicate())
	out["killed"] = false
	if not Net.is_authority() or destroyed or van == null:
		out["amount"] = 0.0
		return out
	var amount: float = maxf(float(info.get("amount", 0.0)), 0.0)
	var zone: int = int(info.get("zone", Enums.HitZone.BODY))
	if int(info.get("type", Enums.DamageType.BULLET)) == Enums.DamageType.EXPLOSION:
		amount *= van.p_float("explosive_mult", 1.0)
	var dealt: float = 0.0
	if zone == Enums.HitZone.WEAKPOINT:
		amount *= van.p_float("weakspot_mult", 1.0)
	elif armor_hp > 0.0:
		var absorbed: float = minf(amount, armor_hp)
		armor_hp -= absorbed
		dealt += absorbed
		amount -= absorbed
		out["armor_hit"] = true
	var to_health: float = minf(amount, health)
	health -= to_health
	dealt += to_health
	out["amount"] = dealt
	out["armor_left"] = armor_hp
	out["health_left"] = health
	if health <= 0.0:
		out["killed"] = true
	EventBus.damage_applied.emit(van.net_id, attacker_net_id, out)
	Net.replicate_event(&"damage_applied", [van.net_id, attacker_net_id, out])
	if health <= 0.0:
		van.turret_destroyed(attacker_net_id)
	return out


# --- Fire (server) -----------------------------------------------------------------------------

func tick(delta: float) -> void:
	if not armed or destroyed or van == null:
		return
	_cool -= delta
	_retarget_left -= delta
	var range_m: float = van.p_float("range_m", 60.0)
	if _retarget_left <= 0.0 or target == null or not is_instance_valid(target) or not _can_engage(target, range_m):
		_retarget_left = van.p_float("retarget_s", 0.5)
		var nt: CrewController = _pick_target(range_m)
		if nt != target:
			_aim_wait = van.p_float("aim_delay_s", 1.0)
		target = nt
	var aim: Vector3 = Vector3.INF
	if target != null:
		aim = CombatSystem.target_center(target)
		_last_seen = aim
		_suppress_left = van.p_float("suppress_s", 2.0)
	elif _last_seen != Vector3.INF and _suppress_left > 0.0:
		_suppress_left -= delta
		aim = _last_seen
	if aim == Vector3.INF:
		_burst_left = 0.0
		return
	var aligned: bool = _turn_toward(aim, delta)
	if _aim_wait > 0.0:
		_aim_wait -= delta
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left <= 0.0:
			_burst_left = van.p_float("burst_s", 2.5)
		return
	if _burst_left <= 0.0:
		_burst_left = van.p_float("burst_s", 2.5)
	_burst_left -= delta
	if _burst_left <= 0.0:
		_pause_left = van.p_float("burst_pause_s", 1.2)
	if aligned and _cool <= 0.0:
		_cool = van.p_float("fire_interval_s", 0.12)
		_fire(aim)


## Rotate toward `aim`; true when both axes are within aim_tolerance_deg.
func _turn_toward(aim: Vector3, delta: float) -> bool:
	if yaw_node == null or pitch_node == null:
		return true
	var parent3: Node3D = yaw_node.get_parent() as Node3D
	var local: Vector3 = parent3.global_transform.affine_inverse() * aim - yaw_node.position
	var want_yaw: float = atan2(-local.x, -local.z)
	var origin_p: Vector3 = parent3.global_transform.affine_inverse() * pitch_node.global_position
	var rel: Vector3 = parent3.global_transform.affine_inverse() * aim - origin_p
	var want_pitch: float = clampf(atan2(rel.y, Vector2(rel.x, rel.z).length()), deg_to_rad(-40.0), deg_to_rad(50.0))
	var dy: float = wrapf(want_yaw - yaw, -PI, PI)
	var dp: float = want_pitch - pitch
	var ys: float = deg_to_rad(van.p_float("turn_deg_s", 75.0)) * delta
	var ps: float = deg_to_rad(van.p_float("pitch_deg_s", 60.0)) * delta
	set_pose(wrapf(yaw + clampf(dy, -ys, ys), -PI, PI), pitch + clampf(dp, -ps, ps))
	var tol: float = deg_to_rad(van.p_float("aim_tolerance_deg", 5.0))
	return absf(wrapf(want_yaw - yaw, -PI, PI)) <= tol and absf(want_pitch - pitch) <= tol


func _pick_target(range_m: float) -> CrewController:
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt == null:
		return null
	var best: CrewController = null
	var best_d: float = INF
	for c: CrewController in rt.crew_members():
		if not _can_engage(c, range_m):
			continue
		var d: float = muzzle_position().distance_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best


func _can_engage(c: CrewController, range_m: float) -> bool:
	if c == null or not is_instance_valid(c) or c.crew_state == Enums.CrewState.CUSTODY:
		return false
	if c.crew_state == Enums.CrewState.DOWNED and (c.weapons == null or not c.weapons.is_shooting()):
		return false  # L2.5: no shooting a downed player who is not shooting
	var aim: Vector3 = CombatSystem.target_center(c)
	if muzzle_position().distance_to(aim) > range_m:
		return false
	return CombatSystem.has_los(self, muzzle_position(), aim, [c, van.body])


func _fire(aim: Vector3) -> void:
	var from: Vector3 = muzzle_position()
	var weapon_id: StringName = StringName(van.params.get("weapon_id", &"weapon.npc_lmg"))
	shots_fired += 1
	EventBus.weapon_fired.emit(van.net_id, weapon_id, false, from)
	var rt: HeistRuntime = HeistRuntime.of(self)
	var hit: bool = false
	if target != null and is_instance_valid(target):
		var chance: float = CombatTweak.data().npc_hit_chance(from.distance_to(aim), difficulty) * van.p_float("accuracy_mult", 0.6)
		hit = GameRng.stream(&"npc_fire").randf() < chance
	var to: Vector3 = aim
	if not hit:
		var rng: RandomNumberGenerator = GameRng.stream(&"npc_fire")
		to = aim + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.4, 0.6), rng.randf_range(-0.8, 0.8))
	var tid: int = NetIds.of(target) if hit else 0
	var mode: int = ShotFx.MODE_SHOT_HIT if hit else ShotFx.MODE_SHOT_MISS
	ShotFx.play_impact(van, from, to, tid, mode)
	if rt != null and rt.net_sync != null:
		rt.net_sync.relay_impact_fx(van.net_id, from, to, tid, mode)
	if hit:
		hits_landed += 1
		var info: Dictionary = Damage.info(van.p_float("damage", 10.0, difficulty), Enums.DamageType.BULLET,
			Enums.HitZone.BODY, weapon_id, aim, (aim - from).normalized(), van.net_id)
		target.take_hit(info, van.net_id)
