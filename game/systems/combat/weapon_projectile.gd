## A fired arrow, bolt or grenade (B4-18, D-055; L3.6, P5). Owner: ENV A.
## Spawned by SpecialWeapons.spawn_projectile under HeistRuntime.dynamic_root with a net_id, so
## HeistNetSync replicates the spawn (with `params`), its `stuck` state and its removal. The server
## simulates flight (gravity, swept ray per physics frame) and impact: explosive rounds call
## Explosion.apply (L3.6 falloff, no friendly fire), others deliver one BULLET hit through
## CombatSystem.deliver_hit. A retrievable arrow then stays where it landed until its owner walks
## over it (one round back to the reserve) or `despawn_s` runs out. Clients only fly the visual.
class_name WeaponProjectile
extends Node3D

const GROUP: StringName = &"weapon_projectile"
## A dud (explosive round inside arm_distance_m) hits for this share of its damage (◇).
const DUD_DAMAGE_MULT: float = 0.1
const MAX_PASS_THROUGH: int = 4

var net_id: int = 0
## Spawn data (replicated): velocity, gravity_mult, lifetime_s, damage, headshot_bonus, weapon_id,
## weapon_slot, owner_slot, attacker, armor_pierce, shield_pierce, radius_m, arm_distance_m,
## retrievable, pickup_radius_m, despawn_s.
var params: Dictionary = {}
## Landed and waiting to be picked up (retrievable arrows).
var stuck: bool = false

var _vel: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _travelled: float = 0.0
var _started: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	if get_node_or_null(^"Visual") == null:
		add_child(_make_visual())


func _physics_process(delta: float) -> void:
	if not _started:
		_started = true
		_vel = params.get("velocity", Vector3.ZERO) as Vector3
	_age += delta
	if stuck:
		if Net.is_authority():
			_tick_pickup()
		return
	if _age > float(params.get("lifetime_s", 10.0)):
		_remove()
		return
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_vel.y -= g * float(params.get("gravity_mult", 1.0)) * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + _vel * delta
	if Net.is_authority():
		var hit: Dictionary = _sweep(from, to)
		if not hit.is_empty():
			_impact(hit)
			return
	_travelled += from.distance_to(to)
	global_position = to
	if _vel.length() > 0.01:
		look_at(to + _vel, Vector3.UP if absf(_vel.normalized().y) < 0.99 else Vector3.RIGHT)


## Server: first world/hitbox contact on from -> to, skipping crew members (no friendly fire).
func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	var tw: CombatTweak = CombatTweak.data()
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, tw.hitscan_mask | tw.los_mask)
	q.collide_with_areas = true
	var ex: Array[RID] = []
	for i: int in range(MAX_PASS_THROUGH):
		q.exclude = ex
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return {}
		var t: Object = CombatSystem.resolve_collider(hit.get("collider"))
		if not (t is CrewController) and not (hit.get("collider") is CrewController):
			hit["target"] = t
			return hit
		ex.append(hit.get("rid") as RID)
	return {}


func _impact(hit: Dictionary) -> void:
	var pos: Vector3 = hit.get("position", global_position)
	var attacker: int = int(params.get("attacker", 0))
	var wid: StringName = StringName(params.get("weapon_id", &""))
	var dmg: float = float(params.get("damage", 0.0))
	var radius: float = float(params.get("radius_m", 0.0))
	var cue_id: StringName = StringName(params.get("impact_cue", ""))
	if cue_id != &"":  # [R] audio_cues.md v1.1: bow/crossbow impact, launcher explode
		EventBus.audio_cue_requested.emit(cue_id, pos, attacker)
		Net.replicate_event(&"audio_cue_requested", [cue_id, pos, attacker])
	var armed: bool = _travelled + global_position.distance_to(pos) >= float(params.get("arm_distance_m", 0.0))
	global_position = pos
	if radius > 0.0 and armed:
		Explosion.apply(self, pos - (_vel.normalized() * 0.05), radius, dmg, attacker, wid)  # L3.6
		_remove()
		return
	var t: Object = hit.get("target") as Object
	if t != null and is_instance_valid(t):
		var info: Dictionary = Damage.info(dmg * (DUD_DAMAGE_MULT if radius > 0.0 else 1.0), Enums.DamageType.BULLET,
			Damage.zone_of(hit.get("collider") as Object), wid, pos, _vel.normalized(), attacker)
		info["headshot_bonus"] = float(params.get("headshot_bonus", 1.0))
		info["pierced_armor"] = CombatSystem.roll_armor_pierce(float(params.get("armor_pierce", 0.0)))
		info["shield_pierce"] = bool(params.get("shield_pierce", false))
		CombatSystem.deliver_hit(t, info, attacker)
	if bool(params.get("retrievable", false)) and radius <= 0.0:
		stuck = true
		_age = 0.0
		return
	_remove()


## Server: the owner walks over a landed arrow -> one round back (if that weapon is missing ammo).
func _tick_pickup() -> void:
	if _age > float(params.get("despawn_s", 60.0)):
		_remove()
		return
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt == null:
		return
	var r: float = float(params.get("pickup_radius_m", 1.0))
	var ws: int = int(params.get("weapon_slot", Enums.WeaponSlot.PRIMARY))
	for crew: CrewController in rt.crew_members():
		if crew.slot != int(params.get("owner_slot", -1)) or crew.weapons == null:
			continue
		if crew.crew_state != Enums.CrewState.NORMAL and crew.crew_state != Enums.CrewState.SWAN_SONG:
			continue
		var w: CrewWeapons = crew.weapons
		if w.weapon_id(ws) != StringName(params.get("weapon_id", &"")):
			continue
		if crew.global_position.distance_to(global_position) > r + 0.9:
			continue
		if DeployablePrefab.max_ammo(crew, ws) - w.mag(ws) - w.reserve(ws) <= 0:
			continue
		w.set_ammo(ws, w.mag(ws), w.reserve(ws) + 1)
		_remove()
		return


func _remove() -> void:
	if is_queued_for_deletion():
		return
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


func _net_state() -> Dictionary:
	return {"stuck": stuck, "pos": global_position}


func _apply_net_state(d: Dictionary) -> void:
	if bool(d.get("stuck", false)) and not stuck:
		stuck = true
		global_position = d.get("pos", global_position) as Vector3


## Original placeholder visual (no assets): a thin shaft for arrows/bolts, a slug for grenades.
func _make_visual() -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Visual"
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	if float(params.get("radius_m", 0.0)) > 0.0:
		var s: SphereMesh = SphereMesh.new()
		s.radius = 0.02
		s.height = 0.05
		mat.albedo_color = Color(0.3, 0.32, 0.2)
		s.material = mat
		mi.mesh = s
	else:
		var b: BoxMesh = BoxMesh.new()
		b.size = Vector3(0.008, 0.008, 0.7)
		mat.albedo_color = Color(0.45, 0.35, 0.22)
		b.material = mat
		mi.mesh = b
	return mi
