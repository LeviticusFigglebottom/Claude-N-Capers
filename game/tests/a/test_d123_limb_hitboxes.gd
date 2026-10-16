## D-123: limb hitboxes (upper arms, thighs) on a rigged NPC (NpcLimbHitboxes). A limb box is zone BODY: the
## BODY multiplier (1.0), never a headshot, a body hit for armor / stats / kill info, PD2 damage unchanged. Its
## A-side sub-zone (`limb` in the hit claim and DamageInfo) drives the AnimDriver shoulder / leg flinch. The boxes
## ride BoneAttachment3Ds of their bones. Runs on a real cast rig; a sub-case whose clip the rig lacks is skipped.
extends TestCase

const HINT_SCRIPT: String = "extends Node\nvar anim_hint: StringName = &\"idle\"\n"
const CHAR_ID: String = "dock_worker"
const BONES: Dictionary = {
	&"shoulder_l": "upper_arm.L", &"shoulder_r": "upper_arm.R", &"leg_l": "thigh.L", &"leg_r": "thigh.R",
}

var _nodes: Array[Node] = []
var _rt: HeistRuntime = null


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_physics_frames(2)


func _npc(pos: Vector3, net_id: int = 0) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = &"guard"
	npc.net_id = net_id
	npc.visual_scene = load(NpcVisuals.scene_path(CHAR_ID)) as PackedScene
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	npc.add_child(visual)
	var gs: GDScript = GDScript.new()
	gs.source_code = HINT_SCRIPT
	gs.reload()
	var brain: Node = Node.new()
	brain.name = "Brain"
	brain.set_script(gs)
	npc.add_child(brain)
	npc.position = pos
	add_child(npc)
	_nodes.append(npc)
	npc.max_health = 100000.0
	npc.health = npc.max_health
	npc.alert_state = Enums.AlertState.COMBAT  # no S3.6 one-shot rule
	var def: EnemyDef = EnemyDef.new()
	def.headshot_mult = [3.0]
	npc.enemy_def = def
	return npc


func _box(npc: NpcBase, sub: StringName) -> Hitbox:
	for hb: Hitbox in NpcLimbHitboxes.boxes(npc):
		if hb.limb == sub:
			return hb
	return null


func _rigged(npc: NpcBase) -> bool:
	if NpcLimbHitboxes.skeleton_of(npc) == null:
		print("[d123] skip: no rig for %s (ENV D assets not checked out)" % CHAR_ID)
		return false
	return true


## The first hitbox on the ray from -> to (areas on the hitboxes layer only).
func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, Hitbox.LAYER_HITBOXES)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	return get_viewport().world_3d.direct_space_state.intersect_ray(q)


## A DamageInfo for a shot that hit `collider` at `pos` along `dir`, built the way CrewWeapons + CombatSystem do.
func _shot(collider: Object, pos: Vector3, dir: Vector3) -> Dictionary:
	var info: Dictionary = Damage.info(40.0, Enums.DamageType.BULLET, Damage.zone_of(collider), &"weapon.kestrel_p9",
		pos, dir)
	var limb: StringName = NpcLimbHitboxes.sanitize(
		NpcLimbHitboxes.limb_at(collider, pos, dir, get_viewport().world_3d.direct_space_state), int(info["zone"]))
	if limb != &"":
		info["limb"] = limb
	return info


func test_d123_four_limb_boxes_on_their_bones() -> void:
	var npc: NpcBase = _npc(Vector3(-120, 0, 0))
	await wait_physics_frames(2)
	if not _rigged(npc):
		return
	var boxes: Array[Hitbox] = NpcLimbHitboxes.boxes(npc)
	assert_eq(boxes.size(), 4, "upper arms + thighs")
	for sub: StringName in BONES:
		var hb: Hitbox = _box(npc, sub)
		assert_true(hb != null, "a %s box" % sub)
		if hb == null:
			continue
		assert_eq(hb.hit_zone, Enums.HitZone.BODY, "%s: zone BODY (the BODY multiplier)" % sub)
		assert_eq(hb.get_damage_target(), npc, "%s routes to the NPC" % sub)
		assert_eq((hb.get_parent() as BoneAttachment3D).bone_name, String(BONES[sub]), "%s on its bone" % sub)
		assert_eq(hb.collision_layer, Hitbox.LAYER_HITBOXES, "%s live on the hitboxes layer" % sub)
	assert_eq(NpcLimbHitboxes.ensure(npc).size(), 4, "idempotent")
	npc.take_hit(Damage.info(1.0e7, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", npc.global_position, Vector3.FORWARD))
	assert_false(npc.alive, "killed")
	for hb: Hitbox in NpcLimbHitboxes.boxes(npc):
		assert_eq(hb.collision_layer, 0, "%s off with the live hitboxes at death" % hb.limb)
	assert_true(npc.get_node_or_null(NpcBase.CORPSE_HITBOX) != null, "the corpse hitbox is untouched (D-121)")


func test_d123_limb_boxes_follow_their_bones() -> void:
	var npc: NpcBase = _npc(Vector3(-120, 0, 10))
	await wait_physics_frames(2)
	if not _rigged(npc):
		return
	var skel: Skeleton3D = NpcLimbHitboxes.skeleton_of(npc)
	var ap: AnimationPlayer = AnimDriver.find_player(npc)
	ap.active = false  # hold the pose we set by hand
	for sub: StringName in BONES:
		var hb: Hitbox = _box(npc, sub)
		var b: int = skel.find_bone(String(BONES[sub]))
		var before: Vector3 = hb.global_position
		skel.set_bone_pose_rotation(b, skel.get_bone_pose_rotation(b) * Quaternion(Vector3.RIGHT, 1.2))
		skel.force_update_all_bone_transforms()
		await wait_frames(2)
		var shape: CollisionShape3D = hb.get_node(^"Shape") as CollisionShape3D
		var want: Vector3 = (skel.global_transform * skel.get_bone_global_pose(b)) * shape.position
		assert_true(shape.global_position.distance_to(want) < 0.005,
			"%s box centre on its bone's pose (%s vs %s)" % [sub, shape.global_position, want])
		assert_true(hb.global_position.distance_to(before) < 0.005, "%s pivot stays on the joint" % sub)
		var bone_axis: Vector3 = (skel.global_transform.basis * skel.get_bone_global_pose(b).basis).y.normalized()
		assert_true(shape.global_basis.y.normalized().dot(bone_axis) > 0.999, "%s capsule along its bone" % sub)
	# Moving the NPC carries the boxes along.
	var hb0: Hitbox = _box(npc, &"leg_r")
	var p0: Vector3 = hb0.global_position
	npc.global_position += Vector3(2, 0, 0)
	await wait_frames(2)
	assert_true(hb0.global_position.distance_to(p0 + Vector3(2, 0, 0)) < 0.005, "the box moves with the body")


func test_d123_limb_hit_deals_exactly_body_damage() -> void:
	var a: NpcBase = _npc(Vector3(-120, 0, 20))
	var b: NpcBase = _npc(Vector3(-118, 0, 20))
	await wait_physics_frames(3)
	if not _rigged(a):
		return
	var dir: Vector3 = Vector3(0, 0, -1)
	var got: Dictionary = {}
	for sub: StringName in BONES:
		var hb: Hitbox = _box(a, sub)
		var c: Vector3 = (hb.get_node(^"Shape") as Node3D).global_position
		var info: Dictionary = Damage.info(40.0, Enums.DamageType.BULLET, Damage.zone_of(hb), &"", c, dir)
		info["limb"] = Hitbox.limb_of(hb)
		var h0: float = a.health
		var out: Dictionary = a.take_hit(info)
		got[sub] = h0 - a.health
		assert_eq(int(out["zone"]), Enums.HitZone.BODY, "%s: a body hit in the final info" % sub)
		assert_eq(StringName(out.get("limb", &"")), sub, "%s: the sub-zone rides along" % sub)
	var hb_b: float = b.health
	b.take_hit(Damage.info(40.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", b.global_position + Vector3(0, 1, 0), dir))
	var body: float = hb_b - b.health
	var h1: float = b.health
	b.take_hit(Damage.info(40.0, Enums.DamageType.BULLET, Enums.HitZone.HEAD, &"", b.head_position(), dir))
	assert_near(h1 - b.health, 120.0, 0.001, "control: the head takes x3 (headshot_mult)")
	assert_near(body, 40.0, 0.001, "control: body damage x1")
	for sub: StringName in got:
		assert_near(float(got[sub]), body, 0.0001, "%s: exactly the BODY damage" % sub)


func test_d123_real_ray_on_a_limb_is_a_body_hit() -> void:
	var npc: NpcBase = _npc(Vector3(-120, 0, 30))
	await wait_physics_frames(3)
	if not _rigged(npc):
		return
	# From the left side onto the left upper arm: the ray meets the BODY hull or the arm box first (either is a
	# BODY hit); on the hull the probe names the limb inside it.
	var arm: Hitbox = _box(npc, &"shoulder_l")
	var c: Vector3 = (arm.get_node(^"Shape") as Node3D).global_position
	var side: Vector3 = (c - npc.global_position)
	side.y = 0.0
	side = side.normalized()
	var from: Vector3 = c + side * 2.0
	var hit: Dictionary = _ray(from, c - side * 0.05)
	assert_false(hit.is_empty(), "the side ray hits the NPC")
	var col: Object = hit.get("collider")
	assert_eq(Damage.find_target(col), npc, "on this NPC")
	var info: Dictionary = _shot(col, hit["position"], -side)
	assert_eq(int(info["zone"]), Enums.HitZone.BODY, "zone BODY")
	assert_eq(StringName(info.get("limb", &"")), &"shoulder_l", "the outer side of the left arm is shoulder_l")
	var h0: float = npc.health
	var out: Dictionary = npc.take_hit(info)
	assert_near(h0 - npc.health, 40.0, 0.0001, "BODY damage, no headshot multiplier")
	assert_eq(int(out["zone"]), Enums.HitZone.BODY, "not a headshot")
	# A thigh through the hull from the front.
	for sub: StringName in [&"leg_l", &"leg_r"]:
		var thigh: Node3D = _box(npc, sub).get_node(^"Shape") as Node3D
		var fwd: Vector3 = -npc.global_basis.z
		var tc: Vector3 = thigh.global_position
		var th: Dictionary = _ray(tc + fwd * 2.0, tc - fwd * 2.0)
		assert_false(th.is_empty(), "%s: the front ray hits" % sub)
		var ti: Dictionary = _shot(th.get("collider"), th["position"], -fwd)
		assert_eq(int(ti["zone"]), Enums.HitZone.BODY, "%s: zone BODY" % sub)
		assert_eq(StringName(ti.get("limb", &"")), sub, "%s: the probe names the thigh inside the hull" % sub)
	# The chest centre is no limb; a HEAD hit never carries one.
	var chest: Vector3 = npc.global_position + Vector3(0, 1.25, 0)
	var fwd2: Vector3 = -npc.global_basis.z
	var ch: Dictionary = _ray(chest + fwd2 * 2.0, chest - fwd2 * 2.0)
	assert_eq(StringName(_shot(ch.get("collider"), ch["position"], -fwd2).get("limb", &"")), &"", "chest: no limb")
	assert_eq(NpcLimbHitboxes.sanitize(&"shoulder_l", Enums.HitZone.HEAD), &"", "no limb on a HEAD hit")
	assert_eq(NpcLimbHitboxes.sanitize(&"elbow", Enums.HitZone.BODY), &"", "unknown sub-zones dropped")


func test_d123_limb_claim_counts_as_body_hit() -> void:
	var l: Loadout = Loadout.new()
	l.primary = &"weapon.brute_12"
	_rt = await HeistLauncher.launch(&"unit_map", 123, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "crew_ai": false, "loadouts": {0: l}})
	await wait_physics_frames(1)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var g: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, g.global_position + Vector3(0, 0, 3.0)))
	await wait_physics_frames(3)
	g.notify_crew_spotted(c)
	await wait_physics_frames(1)
	g.max_health = 100000.0
	g.health = g.max_health
	var infos: Array[Dictionary] = []
	var cb: Callable = func(v: int, _a: int, info: Dictionary) -> void:
		if v == g.net_id:
			infos.append(info)
	EventBus.damage_applied.connect(cb)
	var ws: int = Enums.WeaponSlot.PRIMARY
	var eye: Vector3 = c.eye_position()
	var pt: Vector3 = g.global_position + Vector3(0, 0.9, 0)
	var d: float = eye.distance_to(pt)
	var claim: Dictionary = {
		"seq": 7000, "weapon_slot": ws, "weapon_id": &"weapon.brute_12", "origin": eye,
		"direction": (pt - eye).normalized(),
		"hits": [
			{"target_id": g.net_id, "zone": Enums.HitZone.BODY, "distance": d, "position": pt},
			{"target_id": g.net_id, "zone": Enums.HitZone.BODY, "distance": d, "position": pt, "limb": &"leg_l"},
			{"target_id": g.net_id, "zone": Enums.HitZone.BODY, "distance": d, "position": pt, "limb": &"bogus"},
		],
	}
	var res: Dictionary = CombatSystem.validate_and_apply(claim, c)
	EventBus.damage_applied.disconnect(cb)
	assert_true(bool(res["accepted"]), "claim accepted: %s" % res["reason"])
	assert_eq(infos.size(), 3, "three pellets landed")
	if infos.size() == 3:
		assert_near(float(infos[1]["amount"]), float(infos[0]["amount"]), 0.0001, "the limb pellet = the body pellet")
		assert_eq(int(infos[1]["zone"]), Enums.HitZone.BODY, "zone BODY")
		assert_eq(StringName(infos[1].get("limb", &"")), &"leg_l", "the sub-zone reaches damage_applied")
		assert_false(infos[2].has("limb"), "a bogus sub-zone is dropped")
	var st: CrewStatsService = CrewStatsService.of(c)
	if st != null:
		assert_eq(st.value(c.slot, &"hits"), 1, "a hit")
		assert_eq(st.value(c.slot, &"headshots"), 0, "not a headshot")


func test_d123_limb_hits_trigger_shoulder_and_leg_flinches() -> void:
	var npc: NpcBase = _npc(Vector3(-120, 0, 40), 95123)
	await wait_physics_frames(2)
	if not _rigged(npc):
		return
	var d: AnimDriver = AnimDriver.of(npc)
	var cases: Array = [
		[&"shoulder_l", &"hit_shoulder_l"], [&"shoulder_r", &"hit_shoulder_r"],
		[&"leg_l", &"hit_leg_l"], [&"leg_r", &"hit_leg_r"],
	]
	for cs: Array in cases:
		var clip: StringName = cs[1]
		if not d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, clip]):
			print("[d123] skip %s: the rig has no clip" % clip)
			continue
		# The real box: its centre, so the info is exactly what a shot on that limb sends.
		var hb: Hitbox = _box(npc, cs[0])
		var c: Vector3 = (hb.get_node(^"Shape") as Node3D).global_position
		var info: Dictionary = Damage.info(12.0, Enums.DamageType.BULLET, Damage.zone_of(hb), &"", c, Vector3(0, 0, 1))
		info["limb"] = Hitbox.limb_of(hb)
		d._last_hit_react_t = -100.0
		var out: Dictionary = npc.take_hit(info)  # server path: emits damage_applied with the sub-zone
		assert_eq(int(out["zone"]), Enums.HitZone.BODY, "%s: a BODY hit" % cs[0])
		d.tick(0.016)
		assert_eq(d.clip, clip, "%s box -> %s" % [cs[0], clip])
	# The sub-zone wins over the position (a crouched / posed body), and a plain BODY hit stays hit_chest.
	if d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, AnimDriver.HIT_SHOULDER_R]):
		var odd: Dictionary = Damage.info(12.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"",
			npc.global_position + Vector3(-0.2, 0.3, 0), Vector3(0, 0, 1))
		odd["limb"] = &"shoulder_r"
		assert_eq(d.hit_zone_clip(odd), AnimDriver.HIT_SHOULDER_R, "sub-zone over position")
	if d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, AnimDriver.HIT_CHEST]):
		var plain: Dictionary = Damage.info(12.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"",
			npc.global_position + Vector3(0, 1.2, 0), Vector3(0, 0, 1))
		assert_eq(d.hit_zone_clip(plain), AnimDriver.HIT_CHEST, "no sub-zone: hit_chest")
	var head: Dictionary = Damage.info(12.0, Enums.DamageType.BULLET, Enums.HitZone.HEAD, &"", npc.head_position(),
		Vector3(0, 0, 1))
	head["limb"] = &"leg_l"
	assert_true(d.hit_zone_clip(head) != AnimDriver.HIT_LEG_L, "HEAD ignores a stray sub-zone")
