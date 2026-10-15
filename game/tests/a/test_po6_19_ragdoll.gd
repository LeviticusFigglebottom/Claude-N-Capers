## PO6-19 (D-114 §7): ragdoll / body propulsion (NpcRagdoll, RagdollTweak) on ENV D's physical-bones ragdoll
## (Security Officer scene, world/characters/_tools/RAGDOLL.md). Headless physics on a floor:
## point-blank shotgun kill -> ragdoll at once, thrown back; grenade on a group -> all ragdolled outward;
## pistol kill at range -> death animation (no ragdoll) then a short settle; corpse shot -> blood_hit at the
## hit point + nudge + re-freeze; the active cap; the freeze (simulator off, pose baked, root under the hips,
## corpse hitbox where the body lies, replicated start / pose); body bagging still works on a frozen corpse.
extends TestCase

const SCENE: String = "res://world/characters/security_officer/security_officer.tscn"
const SHOTGUN: StringName = &"weapon.brute_12"
const PISTOL: StringName = &"weapon.kestrel_p9"
const PELLETS: int = 10

var _nodes: Array[Node] = []
var _hits: Array[Array] = []
var _floor: StaticBody3D = null


func before_each() -> void:
	_hits = []
	EventBus.blood_hit.connect(_on_blood_hit)
	_floor = StaticBody3D.new()
	_floor.collision_layer = 1  # world_static
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	_floor.add_child(col)
	add_child(_floor)


func after_each() -> void:
	EventBus.blood_hit.disconnect(_on_blood_hit)
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	if is_instance_valid(_floor):
		_floor.queue_free()
	await wait_physics_frames(2)


func _on_blood_hit(a0: Variant, a1: Variant, a2: Variant, a3: Variant, a4: Variant, a5: Variant, a6: Variant,
		a7: Variant) -> void:
	_hits.append([a0, a1, a2, a3, a4, a5, a6, a7])


## A guard wearing the Security Officer (with its Ragdoll), alerted (no S3.6 one-shot), 100 HP, facing -Z.
func _npc(pos: Vector3, net_id: int = 0) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = &"guard"
	npc.visual_scene = load(SCENE) as PackedScene
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	npc.add_child(visual)
	npc.position = pos
	add_child(npc)
	_nodes.append(npc)
	npc.net_id = net_id
	npc.max_health = 100.0
	npc.health = 100.0
	npc.alert_state = Enums.AlertState.COMBAT
	return npc


static func _info(amount: float, weapon: StringName, at: Vector3, dir: Vector3, range_m: float) -> Dictionary:
	var d: Dictionary = Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, weapon, at, dir)
	d["range_m"] = range_m
	return d


## One shotgun shot: every pellet on the chest in the same physics frame (CombatSystem delivers them in a loop).
func _shotgun(npc: NpcBase, dir: Vector3, range_m: float) -> void:
	var chest: Vector3 = npc.global_position + Vector3(0, 1.3, 0)
	for i: int in PELLETS:
		npc.take_hit(_info(30.0, SHOTGUN, chest + Vector3(0.02 * i, 0, 0), dir, range_m))


static func _hips(rd: NpcRagdoll) -> Vector3:
	for pb: PhysicalBone3D in rd.bodies:
		if pb.name == NpcRagdoll.HIPS_BODY:
			return pb.global_position
	return Vector3.INF


## Hips drawn by the skeleton (baked pose when frozen).
static func _skel_hips(rd: NpcRagdoll) -> Vector3:
	var hb: PhysicalBone3D = rd.bodies[rd._body_index(NpcRagdoll.HIPS_BODY)]
	var bi: int = rd.skel.find_bone(hb.bone_name)
	return (rd.skel.global_transform * rd.skel.get_bone_global_pose(bi) * hb.body_offset).origin


func _settle_frames() -> int:
	return roundi((RagdollTweak.data().settle_s + 0.5) * Engine.physics_ticks_per_second)


func test_character_npc_gets_the_ragdoll_runtime_placeholder_does_not() -> void:
	var npc: NpcBase = _npc(Vector3(0, 0, 0))
	var rd: NpcRagdoll = NpcRagdoll.of(npc)
	assert_true(rd != null, "Security Officer visual -> NpcRagdoll")
	if rd != null:
		assert_eq(rd.bodies.size(), 12, "12 physical bones")
		assert_false(rd.sim.active, "inactive while alive")
	var cap: NpcBase = NpcBase.new()
	var v: Node3D = Node3D.new()
	v.name = "Visual"
	cap.add_child(v)
	NpcVisuals.disabled = true
	add_child(cap)
	NpcVisuals.disabled = false
	_nodes.append(cap)
	assert_true(NpcRagdoll.of(cap) == null, "capsule placeholder: no ragdoll runtime")
	cap.die({"direction": Vector3(0, 0, 1)})
	assert_true(cap.get_node_or_null(NpcBase.CORPSE_HITBOX) != null, "placeholder corpse is still hittable")


func test_point_blank_shotgun_throws_the_body_back() -> void:
	var npc: NpcBase = _npc(Vector3(30, 0, 0))
	var rd: NpcRagdoll = NpcRagdoll.of(npc)
	await wait_physics_frames(3)
	var start: Vector3 = npc.global_position
	_shotgun(npc, Vector3(0, 0, 1), 2.0)
	assert_false(npc.alive, "killed")
	await wait_physics_frames(3)
	assert_true(rd.engaged and rd.sim.active, "ragdoll started at once (phase %d)" % rd.phase)
	assert_eq(rd.phase, NpcRagdoll.Phase.ACTIVE, "pushed")
	assert_false(rd.player.is_playing(), "AnimationPlayer paused")
	await wait_physics_frames(roundi(1.5 * Engine.physics_ticks_per_second))
	var hips: Vector3 = _hips(rd)
	assert_true(hips.z - start.z > 0.5, "hips thrown back %.2f m along the shot" % (hips.z - start.z))
	assert_true(hips.y < 0.6, "on the floor (hips y %.2f)" % hips.y)


func test_far_shotgun_and_pistol_kills_play_the_death_animation() -> void:
	var a: NpcBase = _npc(Vector3(-30, 0, 0))
	var b: NpcBase = _npc(Vector3(-30, 0, 10))
	await wait_physics_frames(3)
	_shotgun(a, Vector3(0, 0, 1), 15.0)  # pellets beyond shotgun_range_m
	b.take_hit(_info(500.0, PISTOL, b.global_position + Vector3(0, 1.3, 0), Vector3(0, 0, 1), 20.0))
	await wait_physics_frames(3)
	for n: NpcBase in [a, b]:
		var rd: NpcRagdoll = NpcRagdoll.of(n)
		assert_false(n.alive, "killed")
		assert_eq(rd.phase, NpcRagdoll.Phase.ANIM, "death animation first")
		assert_false(rd.engaged or rd.sim.active, "no ragdoll at death")
	await wait_frames(2)
	var d: AnimDriver = AnimDriver.of(b)
	assert_true(String(d.clip).begins_with("death"), "death clip %s" % d.clip)
	# settle_after_anim: once the clip ends a short ragdoll lays the body down, then it freezes.
	var rdb: NpcRagdoll = NpcRagdoll.of(b)
	var tw: RagdollTweak = RagdollTweak.data()
	var ok: bool = await wait_until(func() -> bool: return rdb.freezes > 0,
		tw.anim_wait_max_s + tw.settle_after_anim_s + 1.0)
	assert_true(ok, "settled and frozen after the death clip")
	assert_false(rdb.sim.active, "simulator off after the settle")


func test_grenade_throws_a_group_outward() -> void:
	var c: Vector3 = Vector3(0, 0, 60)
	var npcs: Array[NpcBase] = [_npc(c + Vector3(1.5, 0, 0)), _npc(c + Vector3(-1.5, 0, 0)), _npc(c + Vector3(0, 0, 1.5))]
	await wait_physics_frames(3)
	var res: Array[Dictionary] = Explosion.apply(_floor, c + Vector3(0, 0.3, 0), 5.0, 1000.0, 0, &"weapon.frag")
	assert_eq(res.size(), 3, "three victims")
	await wait_physics_frames(3)
	for n: NpcBase in npcs:
		var rd: NpcRagdoll = NpcRagdoll.of(n)
		assert_false(n.alive, "killed")
		assert_eq(rd.phase, NpcRagdoll.Phase.ACTIVE, "ragdolled")
	await wait_physics_frames(roundi(1.0 * Engine.physics_ticks_per_second))
	for n: NpcBase in npcs:
		var rd: NpcRagdoll = NpcRagdoll.of(n)
		var out: Vector3 = n.global_position - c
		out.y = 0.0
		var moved: Vector3 = _hips(rd) - n.global_position
		moved.y = 0.0
		assert_true(moved.dot(out.normalized()) > 0.5, "%s thrown outward %.2f m" % [n.name, moved.dot(out.normalized())])


func test_corpse_shot_bleeds_at_the_hit_point_and_nudges() -> void:
	var npc: NpcBase = _npc(Vector3(0, 0, -60), 4242)
	var rd: NpcRagdoll = NpcRagdoll.of(npc)
	await wait_physics_frames(3)
	_shotgun(npc, Vector3(0, 0, 1), 2.0)
	# Let the thrown body land and settle on its own (a forced freeze mid-flight would make the nudge's restart
	# fall the rest of the way: order-dependent "a nudge, not a throw" failures in the po6_ batch).
	var settled: bool = await wait_until(func() -> bool: return rd.phase == NpcRagdoll.Phase.FROZEN,
		RagdollTweak.data().settle_s + 1.5)
	assert_true(settled, "settled and frozen on the floor")
	assert_eq(rd.phase, NpcRagdoll.Phase.FROZEN, "frozen")
	var hb: Hitbox = npc.get_node_or_null(NpcBase.CORPSE_HITBOX) as Hitbox
	assert_true(hb != null and hb.collision_layer == Hitbox.LAYER_HITBOXES, "corpse hitbox on the hitboxes layer")
	await wait_physics_frames(2)
	# A combat ray straight down onto the corpse finds it (corpses stay hittable).
	var target: Vector3 = (hb.global_position if hb != null else npc.global_position)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(target + Vector3(0, 2, 0),
		target + Vector3(0, -1, 0), CombatTweak.data().hitscan_mask)
	q.collide_with_areas = true
	var ray: Dictionary = npc.get_world_3d().direct_space_state.intersect_ray(q)
	assert_true(CombatSystem.resolve_collider(ray.get("collider")) == npc, "a bullet ray hits the corpse: %s" % ray)
	var point: Vector3 = ray.get("position", target)
	_hits.clear()
	var before: Vector3 = _skel_hips(rd)
	var freezes: int = rd.freezes
	var res: Dictionary = npc.take_hit(_info(40.0, PISTOL, point, Vector3(0, -0.3, 1).normalized(), 5.0))
	assert_eq(float(res.get("amount", -1.0)), 0.0, "no damage to a corpse")
	assert_eq(_hits.size(), 1, "blood_hit on the corpse")
	if _hits.size() == 1:
		assert_eq(int(_hits[0][0]), 4242, "victim net id")
		assert_true((_hits[0][1] as Vector3).is_equal_approx(point), "at the hit point")
	assert_eq(rd.phase, NpcRagdoll.Phase.STARTING, "restarted from the baked pose")
	await wait_physics_frames(2)
	var moving: bool = false
	for pb: PhysicalBone3D in rd.bodies:
		moving = moving or pb.linear_velocity.length() > 0.02
	assert_true(moving, "nudged")
	var ok: bool = await wait_until(func() -> bool: return rd.freezes > freezes,
		RagdollTweak.data().nudge_settle_s + 0.5)
	assert_true(ok, "re-frozen after ~1 s")
	assert_true(_skel_hips(rd).distance_to(before) < 0.5, "a nudge, not a throw")


func test_active_cap_freezes_the_oldest() -> void:
	var tw: RagdollTweak = RagdollTweak.data()
	var cap: int = tw.max_active
	tw.max_active = 2
	var npcs: Array[NpcBase] = []
	for i: int in 3:
		npcs.append(_npc(Vector3(60, 0, 10.0 * i)))
	await wait_physics_frames(3)
	for n: NpcBase in npcs:
		_shotgun(n, Vector3(0, 0, 1), 1.0)
		await wait_physics_frames(3)
	assert_true(NpcRagdoll.active_count() <= 2, "at most max_active simulate (%d)" % NpcRagdoll.active_count())
	assert_eq(NpcRagdoll.of(npcs[0]).phase, NpcRagdoll.Phase.FROZEN, "the oldest froze first")
	assert_eq(NpcRagdoll.of(npcs[2]).phase, NpcRagdoll.Phase.ACTIVE, "the newest simulates")
	tw.max_active = cap


func test_freeze_bakes_moves_the_root_and_replicates() -> void:
	var npc: NpcBase = _npc(Vector3(-60, 0, 0))
	var rd: NpcRagdoll = NpcRagdoll.of(npc)
	await wait_physics_frames(3)
	_shotgun(npc, Vector3(0, 0, 1), 1.0)
	var ok: bool = await wait_until(func() -> bool: return rd.freezes > 0, RagdollTweak.data().settle_s + 1.0)
	assert_true(ok, "frozen after the settle")
	assert_false(rd.sim.active or rd.sim.is_simulating_physics(), "simulator inactive")
	for pb: PhysicalBone3D in rd.bodies:
		assert_eq(PhysicsServer3D.body_get_collision_layer(pb.get_rid()), 0, "%s stopped colliding" % pb.name)
	await wait_physics_frames(5)
	var hips: Vector3 = _skel_hips(rd)
	assert_true(Vector2(hips.x - npc.global_position.x, hips.z - npc.global_position.z).length() < 0.05,
		"the gameplay root moved under the hips (%s vs %s)" % [npc.global_position, hips])
	assert_true(hips.z > 0.5, "the baked pose stays where the body flew (hips z %.2f)" % hips.z)
	var hb: Hitbox = npc.get_node(NpcBase.CORPSE_HITBOX) as Hitbox
	assert_true(Vector2(hb.global_position.x - hips.x, hb.global_position.z - hips.z).length() < 1.0,
		"the corpse hitbox lies with the body")
	var st: Dictionary = NetEntityCodec.state_of(npc)
	assert_true(st.has("rs") and (st["rs"] as Array).size() == 3, "start fact replicated")
	assert_true(st.has("rp") and ((st["rp"] as Array)[3] as Array).size() == 12, "frozen pose: 12 transforms")
	# A client replica snaps to the server's frozen pose (root, visual offset, baked bones).
	var twin: NpcBase = _npc(Vector3(-60, 0, 20))
	await wait_physics_frames(2)
	twin.die({}, 0)
	var trd: NpcRagdoll = NpcRagdoll.of(twin)
	var rp: Array = st["rp"]
	trd._snap(rp[1] as Vector3, rp[2] as Vector3, rp[3] as Array)
	await wait_physics_frames(2)
	assert_true(twin.global_position.is_equal_approx(npc.global_position), "replica root")
	assert_true(_skel_hips(trd).distance_to(hips) < 0.05, "replica pose matches (%s vs %s)" % [_skel_hips(trd), hips])
	assert_true(NpcRagdoll.owns_pose(twin), "the AnimDriver no longer drives the replica")


func test_bagging_a_frozen_corpse_stops_it() -> void:
	var npc: NpcBase = _npc(Vector3(0, 0, 90))
	var rd: NpcRagdoll = NpcRagdoll.of(npc)
	await wait_physics_frames(3)
	_shotgun(npc, Vector3(0, 0, 1), 1.0)
	await wait_physics_frames(5)
	npc.set_meta(&"bagged", true)
	npc.clear_corpse()  # LootManager.bag_body
	assert_false(rd.sim.active, "a bagged body stops simulating")
	assert_eq((npc.get_node(NpcBase.CORPSE_HITBOX) as Hitbox).collision_layer, 0, "no corpse hitbox once bagged")
	_hits.clear()
	npc.take_hit(_info(40.0, PISTOL, npc.global_position, Vector3(0, 0, 1), 5.0))
	assert_eq(_hits.size(), 0, "a bagged body does not bleed")


## PO6-18 + PO6-19: a kneeling cuffed hostage killed by a pistol never stands up and ends low on the floor.
## Two paths: the rig has ENV D's death_kneel_cuffed -> that clip plays (then the settle); the rig lacks it
## (forced here by removing the clip) -> the frozen kneel hands over to the ragdoll at once and topples.
func _kneeling_hostage(pos: Vector3, drop_clip: bool) -> NpcBase:
	var n: NpcBase = _npc(pos)
	var brain: Node = Node.new()
	brain.name = "Brain"
	var sc: GDScript = GDScript.new()
	sc.source_code = "extends Node\nvar anim_hint: StringName = &\"kneel_cuffed\"\n"
	sc.reload()
	brain.set_script(sc)
	n.add_child(brain)
	await wait_physics_frames(6)
	var lib: AnimationLibrary = AnimDriver.of(n).player.get_animation_library(AnimDriver.LIBRARY)
	if drop_clip and lib.has_animation(&"death_kneel_cuffed"):
		lib = lib.duplicate()  # the scene's library is shared: drop the clip on this rig's copy only
		lib.remove_animation(&"death_kneel_cuffed")
		var ap: AnimationPlayer = AnimDriver.of(n).player
		ap.remove_animation_library(AnimDriver.LIBRARY)
		ap.add_animation_library(AnimDriver.LIBRARY, lib)
		await wait_physics_frames(2)
	assert_eq(AnimDriver.of(n).clip, &"kneel_cuffed", "kneeling before the shot")
	return n


func _head_y(rd: NpcRagdoll) -> float:
	for pb: PhysicalBone3D in rd.bodies:
		if pb.name == "Head":
			return pb.global_position.y
	return INF


func test_kneeling_hostage_without_pose_clip_topples() -> void:
	var n: NpcBase = await _kneeling_hostage(Vector3(30, 0, 0), true)
	n.take_hit(_info(500.0, PISTOL, n.global_position + Vector3(0, 0.9, 0), Vector3(0, 0, 1), 10.0))
	var rd: NpcRagdoll = NpcRagdoll.of(n)
	var ok: bool = await wait_until(func() -> bool: return rd.engaged, 1.0)
	assert_true(ok, "the frozen kneel hands over to the ragdoll within 1 s (not anim_wait_max_s)")
	await wait_until(func() -> bool: return rd.freezes > 0, RagdollTweak.data().settle_s + 2.0)
	assert_true(_head_y(rd) < 0.6, "head ends low on the floor (%.2f m)" % _head_y(rd))


func test_kneeling_hostage_with_pose_clip_plays_it() -> void:
	var probe: NpcBase = _npc(Vector3(40, 0, 0))
	await wait_physics_frames(3)
	var has_clip: bool = AnimDriver.of(probe).player.has_animation("%s/death_kneel_cuffed" % AnimDriver.LIBRARY)
	if not has_clip:
		skip("rig has no death_kneel_cuffed yet (ENV D clip): the topple test covers this rig")
		return
	var n: NpcBase = await _kneeling_hostage(Vector3(30, 0, 6), false)
	var start_head: float = n.global_position.y + 1.2
	n.take_hit(_info(500.0, PISTOL, n.global_position + Vector3(0, 0.9, 0), Vector3(0, 0, 1), 10.0))
	await wait_frames(3)
	assert_eq(AnimDriver.of(n).clip, &"death_kneel_cuffed", "the pose death clip plays")
	var rd: NpcRagdoll = NpcRagdoll.of(n)
	await wait_until(func() -> bool: return rd.freezes > 0,
		RagdollTweak.data().anim_wait_max_s + RagdollTweak.data().settle_after_anim_s + 2.0)
	assert_true(_head_y(rd) < 0.6, "head ends low on the floor (%.2f m)" % _head_y(rd))
	assert_true(_head_y(rd) < start_head, "never rises")
