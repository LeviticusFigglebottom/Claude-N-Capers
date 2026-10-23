## A thrown grenade / knife (A3-12). Owner: ENV A. Spawned by CrewThrowables under HeistRuntime.dynamic_root
## with a net_id, so HeistNetSync replicates the spawn (with `params`), its `landed` state and its removal.
## The server simulates the flight (gravity, swept ray per physics frame, bounce on the world keeping
## CombatTweak.throw_bounce_keep) and the effect by ThrowableDef.kind:
## - frag: at fuse_s after the throw, Explosion.apply (L3.6 falloff, no friendly fire) + noise.
## - concussion: at fuse_s, every NPC in radius_m with blast LOS is stunned concussion_stun_s (stun-immune
##   enemies ignore it) and takes `damage` if > 0; noise.
## - incendiary: on its first contact a fire pool of radius_m burns incendiary_pool_s: NPCs inside are set
##   burning (BurnStatus, DamageType.FIRE, panic roll); crew are never burnt (no friendly fire).
## - throwing_knife: one MELEE hit of `damage` on the first target it touches, then it drops.
## - smoke (D-163 Sicario): on its first contact a smoke cloud of radius_m stays smoke_s (SmokeZones: crew inside avoid
##   crew_bullet_avoid of the bullets, enemies inside hit at npc_accuracy_mult; no LOS blocking, PD2).
## Clients only fly the visual (and show the pool).
class_name ThrownItem
extends Node3D

const GROUP: StringName = &"thrown_item"
const KIND_FRAG: StringName = &"frag"
const KIND_CONCUSSION: StringName = &"concussion"
const KIND_INCENDIARY: StringName = &"incendiary"
const KIND_KNIFE: StringName = &"throwing_knife"
const KIND_SMOKE: StringName = &"smoke_bomb"  # D-163: B's ThrowableDef kind
const KINDS: Array[StringName] = [KIND_FRAG, KIND_CONCUSSION, KIND_INCENDIARY, KIND_KNIFE, KIND_SMOKE]
## D-163 smoke cloud defaults ◇ (params override: radius_m, smoke_s, crew_bullet_avoid, npc_accuracy_mult).
const SMOKE_RADIUS_M: float = 6.0
const SMOKE_S: float = 10.0
const CUE_SMOKE: StringName = &"cue.smoke_bomb"
const POOL_TICK_S: float = 0.25
## audio_cues v1.3 (D-073).
const CUE_FRAG: StringName = &"cue.throwable_frag"
const CUE_CONCUSSION: StringName = &"cue.throwable_concussion"
const CUE_INCENDIARY: StringName = &"cue.throwable_incendiary"
const CUE_FIRE_LOOP: StringName = &"cue.throwable_incendiary_fire"
const CUE_KNIFE_HIT: StringName = &"cue.throwable_knife_hit"
const CUE_KNIFE_HIT_HARD: StringName = &"cue.throwable_knife_hit_hard"

var net_id: int = 0
## Spawn data (replicated): velocity, kind, damage, radius_m, fuse_s, attacker, owner_slot, throwable_id.
var params: Dictionary = {}
## Came to rest (knife dropped) or the incendiary pool is burning.
var landed: bool = false
## Incendiary pool seconds left (> 0 while burning).
var pool_left: float = 0.0

var _vel: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _started: bool = false
var _pool_tick: float = 0.0
var _done: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	if get_node_or_null(^"Visual") == null:
		var id: StringName = StringName(params.get("throwable_id", &""))
		var def: ThrowableDef = ContentDB.throwable(id) if id != &"" else null
		var v: Node3D = def.model.instantiate() as Node3D if def != null and def.model != null else null
		if v != null:
			v.name = "Visual"
			var pin: Node = v.find_child("Pin", true, false)
			if pin is Node3D:
				(pin as Node3D).visible = false  # visual_slots.md Items: the pin stays in the hand
		add_child(v if v != null else _make_visual())


func kind() -> StringName:
	return StringName(params.get("kind", KIND_FRAG))


func _physics_process(delta: float) -> void:
	var tw: CombatTweak = CombatTweak.data()
	if not _started:
		_started = true
		_vel = params.get("velocity", Vector3.ZERO) as Vector3
	_age += delta
	if pool_left > 0.0:
		_tick_pool(delta, tw)
		return
	if _age > tw.throw_lifetime_s:
		_remove()
		return
	if Net.is_authority() and not [KIND_INCENDIARY, KIND_KNIFE, KIND_SMOKE].has(kind()) \
			and _age >= float(params.get("fuse_s", 2.5)):
		_detonate(global_position)
		return
	if landed:
		return
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_vel.y -= g * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + _vel * delta
	if Net.is_authority():
		var hit: Dictionary = _sweep(from, to)
		if not hit.is_empty():
			_contact(hit, tw)
			return
	global_position = to


## Server: first world / hitbox contact on from -> to, skipping crew members (no friendly fire).
func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	var tw: CombatTweak = CombatTweak.data()
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, tw.hitscan_mask | tw.los_mask)
	q.collide_with_areas = true
	var ex: Array[RID] = []
	for _i: int in 4:
		q.exclude = ex
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return {}
		var col: Object = hit.get("collider")
		var t: Object = CombatSystem.resolve_collider(col)
		if not (t is CrewController) and not (col is CrewController):
			hit["target"] = t
			return hit
		ex.append(hit.get("rid") as RID)
	return {}


func _contact(hit: Dictionary, tw: CombatTweak) -> void:
	var pos: Vector3 = hit.get("position", global_position)
	var n: Vector3 = hit.get("normal", Vector3.UP)
	match kind():
		KIND_INCENDIARY:
			global_position = pos + n * 0.05
			_ignite_pool(tw)
		KIND_SMOKE:
			global_position = pos + n * 0.05
			_start_smoke()
		KIND_KNIFE:
			var t: Object = hit.get("target") as Object
			var body: bool = t != null and is_instance_valid(t) and t.has_method(&"take_hit")
			_cue(CUE_KNIFE_HIT if body else CUE_KNIFE_HIT_HARD, pos, int(params.get("attacker", 0)))
			if body:
				var info: Dictionary = Damage.info(float(params.get("damage", 0.0)), Enums.DamageType.MELEE,
					Damage.zone_of(hit.get("collider") as Object), StringName(params.get("throwable_id", &"")), pos,
					_vel.normalized(), int(params.get("attacker", 0)))
				CombatSystem.deliver_hit(t, info, int(params.get("attacker", 0)))
			global_position = pos + n * 0.05
			landed = true
		_:
			global_position = pos + n * 0.05
			_vel = _vel.bounce(n) * tw.throw_bounce_keep  # frag / concussion roll on until the fuse
			if _vel.length() < 0.5 and n.y > 0.7:
				landed = true


func _detonate(pos: Vector3) -> void:
	if _done:
		return
	_done = true
	var tw: CombatTweak = CombatTweak.data()
	var attacker: int = int(params.get("attacker", 0))
	var radius: float = float(params.get("radius_m", 5.0))
	var dmg: float = float(params.get("damage", 0.0))
	var wid: StringName = StringName(params.get("throwable_id", &""))
	_cue(CUE_CONCUSSION if kind() == KIND_CONCUSSION else CUE_FRAG, pos, attacker)
	if kind() == KIND_CONCUSSION:
		ShotFx.explosion(self, pos, radius, &"concussion")  # PO-8 (the frag path emits in Explosion.apply)
		for t: Object in Explosion.targets_in_sphere(self, pos, radius, tw):
			var npc: NpcBase = t as NpcBase
			if npc == null or not npc.alive or not Explosion.blast_los(self, pos, CombatSystem.target_center(npc), npc, tw):
				continue
			npc.stun(tw.concussion_stun_s)
			if dmg > 0.0:
				CombatSystem.deliver_hit(npc, Damage.info(dmg, Enums.DamageType.EXPLOSION, Enums.HitZone.BODY, wid,
					CombatSystem.target_center(npc), Vector3.UP, attacker), attacker)
	else:
		Explosion.apply(self, pos + Vector3(0.0, 0.05, 0.0), radius, dmg, attacker, wid)  # L3.6
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt != null:
		rt.make_noise(pos, tw.throwable_noise_radius_m, &"explosion", attacker)
	_remove()


## Server, B5 `deploy.trip_mine_fire` (Fire Trap, Hot Floor): an incendiary pool of `radius` m burning `duration` s at
## `pos` (the same burn rules as a thrown incendiary; attacker = the trip mine's owner). Null without a runtime.
static func spawn_fire_pool(near: Node, pos: Vector3, radius: float, duration: float, attacker: int, owner_slot: int) -> ThrownItem:
	var rt: HeistRuntime = HeistRuntime.of(near)
	var parent: Node = rt.dynamic_root if rt != null and rt.dynamic_root != null else null
	if parent == null or radius <= 0.0 or duration <= 0.0:
		return null
	var item: ThrownItem = ThrownItem.new()
	item.name = "FirePool_%d" % near.get_instance_id()
	item.params = {"velocity": Vector3.ZERO, "kind": KIND_INCENDIARY, "damage": 0.0, "radius_m": radius, "pool_s": duration,
		"attacker": attacker, "owner_slot": owner_slot, "throwable_id": &""}
	parent.add_child(item, true)
	item.global_position = pos
	NetIds.claim(item)
	item._ignite_pool(CombatTweak.data())
	return item


## D-163: the smoke cloud starts (it counts down through the pool timer; SmokeZones reads it).
func _start_smoke() -> void:
	landed = true
	pool_left = float(params.get("smoke_s", SMOKE_S))
	_cue(CUE_SMOKE, global_position, int(params.get("attacker", 0)))
	_show_pool()


## The cloud radius of a smoke item (m).
func smoke_radius() -> float:
	return float(params.get("radius_m", SMOKE_RADIUS_M))


func _ignite_pool(tw: CombatTweak) -> void:
	landed = true
	pool_left = float(params.get("pool_s", tw.incendiary_pool_s))  # B5: a trip mine's fire sets its own duration
	_pool_tick = 0.0
	_cue(CUE_INCENDIARY, global_position, int(params.get("attacker", 0)))
	_show_pool()


func _tick_pool(delta: float, tw: CombatTweak) -> void:
	pool_left -= delta
	if pool_left <= 0.0:
		if Net.is_authority():
			_remove()
		return
	if not Net.is_authority() or kind() == KIND_SMOKE:
		return  # smoke: SmokeZones reads the live cloud, nothing burns
	_pool_tick -= delta
	if _pool_tick > 0.0:
		return
	_pool_tick = POOL_TICK_S
	var r: float = float(params.get("radius_m", 3.0))
	var flame: Dictionary = {
		"dot_damage_per_s": float(params.get("damage", 0.0)) if float(params.get("damage", 0.0)) > 0.0 else tw.incendiary_burn_dps,
		"dot_duration_s": tw.incendiary_burn_s, "panic_chance": tw.incendiary_panic_chance, "panic_s": tw.incendiary_panic_s,
	}
	for n: Node in get_tree().get_nodes_in_group(G.NPC):
		var npc: NpcBase = n as NpcBase
		if npc == null or not npc.alive:
			continue
		var d: Vector3 = npc.global_position - global_position
		if Vector2(d.x, d.z).length() <= r and absf(d.y) <= 1.5:
			BurnStatus.ignite(npc, int(params.get("attacker", 0)), StringName(params.get("throwable_id", &"")), flame)


func _cue(id: StringName, pos: Vector3, attacker: int) -> void:
	EventBus.audio_cue_requested.emit(id, pos, attacker)
	Net.replicate_event(&"audio_cue_requested", [id, pos, attacker])


func _remove() -> void:
	if is_queued_for_deletion():
		return
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


func _net_state() -> Dictionary:
	return {"landed": landed, "pos": global_position, "pool": pool_left}


func _apply_net_state(d: Dictionary) -> void:
	landed = bool(d.get("landed", landed))
	if landed:
		global_position = d.get("pos", global_position) as Vector3
	var pool: float = float(d.get("pool", 0.0))
	if pool > 0.0 and pool_left <= 0.0:
		pool_left = pool
		_show_pool()


## Every peer: the pool visual and its fire loop (a CueEmitter, stopped when the pool is freed).
func _show_pool() -> void:
	if get_node_or_null(^"Pool") != null:
		return
	if kind() == KIND_SMOKE:
		_show_smoke()
		return
	var fire: CueEmitter = CueEmitter.new()
	fire.name = "FireLoop"
	fire.cue_id = CUE_FIRE_LOOP
	fire.autoplay = true
	add_child(fire)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Pool"
	var cyl: CylinderMesh = CylinderMesh.new()
	var r: float = float(params.get("radius_m", 3.0))
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.05
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	cyl.material = mat
	mi.mesh = cyl
	add_child(mi)


## Every peer: an original placeholder cloud (a translucent grey dome; C's smoke VFX replaces it).
func _show_smoke() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Pool"
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = smoke_radius()
	sm.height = smoke_radius() * 1.2
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.7, 0.72, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.material = mat
	mi.mesh = sm
	add_child(mi)


## Original placeholder visual (no assets): a small dark sphere.
func _make_visual() -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Visual"
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	mi.mesh = sm
	return mi
