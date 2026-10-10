## A3-01b L4.5 Bulwark: scene + shield contract (separate world_dynamic body with `Collision`),
## special_spawned, fixation on one player, SHIELD_ANCHOR doorway holding, shield bangs (cue), the
## dropped shield stays and still blocks, and other specials taking the spot behind it.
extends TestCase

var _rt: HeistRuntime = null
var _cues: Array[StringName] = []
var _cue_cb: Callable = Callable()


func before_each() -> void:
	_rt = await ACombatSpecials.launch(self)
	_cues = []
	_cue_cb = ACombatSpecials.record_cues(_cues)


func after_each() -> void:
	if EventBus.audio_cue_requested.is_connected(_cue_cb):
		EventBus.audio_cue_requested.disconnect(_cue_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(2)


func _loud() -> CrewController:
	var c: CrewController = await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	_rt.stealth.raise_alarm(&"test", 0)
	return c


func test_l4_5_bulwark_scene_and_shield_contract() -> void:
	var spawned: Array[StringName] = []
	var cb: Callable = func(_id: int, t: StringName) -> void: spawned.append(t)
	EventBus.special_spawned.connect(cb)
	var bw: NpcBase = ACombatSpecials.spawn(_rt, "bulwark", Vector3(0, 0.05, -8))
	await wait_physics_frames(3)
	EventBus.special_spawned.disconnect(cb)
	assert_eq(bw.role, &"special")
	assert_true(bw.enemy_def.is_special and bw.enemy_def.id == &"enemy.bulwark", "EnemyDef enemy.bulwark")
	var b: BulwarkBrain = bw.get_node("Brain") as BulwarkBrain
	assert_true(b != null, "BulwarkBrain")
	assert_eq(spawned, [&"bulwark"] as Array[StringName], "special_spawned once with type bulwark")
	var s: BulwarkShield = b.shield
	assert_true(s != null and s.name == "Shield" and s.get_node_or_null("Collision") is CollisionShape3D,
		"Shield scene with Collision")
	assert_eq(s.collision_layer, 1 << 1, "layer world_dynamic")
	assert_true(s.get_parent() == bw, "carried by the Bulwark")
	var local: Vector3 = bw.to_local(s.global_position)
	assert_true(local.z < -0.3, "in front of the Bulwark")


func test_l4_5_fixates_on_one_player() -> void:
	var c: CrewController = await _loud()
	var bw: NpcBase = ACombatSpecials.spawn(_rt, "bulwark", Vector3(0, 0.05, -12), Vector3(0, 0, 1))
	var b: BulwarkBrain = bw.get_node("Brain") as BulwarkBrain
	var locked: bool = await wait_until(func() -> bool: return b.fixated == c, 4.0)
	assert_true(locked, "fixates on the nearest player")
	# A decoy crew-like target: the brain keeps the fixated target across retargets.
	b._retarget_left = 0.0
	await wait_seconds(1.5)
	assert_true(b.combat_target == c and b.fixated == c, "keeps its target")
	c.crew_state = Enums.CrewState.CUSTODY
	b._pick_target()
	assert_true(b.fixated != c, "a target in custody releases the fixation")


func test_l4_5_holds_shield_anchor_and_bangs() -> void:
	var c: CrewController = await _loud()
	var anchor: TacticalPoint = TacticalPoint.new()
	anchor.name = "Doorway"
	anchor.kind = TacticalPoint.Kind.SHIELD_ANCHOR
	_rt.map.get_node("Tactical").add_child(anchor)
	anchor.global_position = c.global_position + Vector3(2, 0, -10)
	var bw: NpcBase = ACombatSpecials.spawn(_rt, "bulwark", c.global_position + Vector3(0, 0, -18), Vector3(0, 0, 1))
	var b: BulwarkBrain = bw.get_node("Brain") as BulwarkBrain
	var st: HeavySpecialTweak = b.special_tweak.duplicate() as HeavySpecialTweak
	st.bulwark_bang_interval_s = Vector2(0.5, 0.5)
	b.special_tweak = st
	var held: bool = await wait_until(func() -> bool:
		return b.cover_point == anchor and b.mode == &"hold" and _flat(bw.global_position - anchor.global_position) < 1.0, 12.0)
	assert_true(held, "holds the SHIELD_ANCHOR (mode %s)" % b.mode)
	var banged: bool = await wait_until(func() -> bool: return b.bangs > 0, 4.0)
	assert_true(banged, "bangs the shield while holding")
	assert_true(_cues.has(&"cue.bulwark_bang"), "cue.bulwark_bang requested")


func test_l4_5_dropped_shield_stays_and_blocks() -> void:
	var bw: NpcBase = ACombatSpecials.spawn(_rt, "bulwark", Vector3(0, 0.05, -8), Vector3(0, 0, 1))
	await wait_physics_frames(3)
	var s: BulwarkShield = (bw.get_node("Brain") as BulwarkBrain).shield
	var where: Vector3 = s.global_position
	bw.die({}, 0)
	await wait_physics_frames(3)
	assert_true(is_instance_valid(s) and s.dropped, "shield dropped")
	assert_true(s.get_parent() == _rt.dynamic_root, "no longer carried")
	assert_true(s.global_position.distance_to(where) < 0.01, "stays where it was dropped")
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		where + Vector3(0, 0, 3), where - Vector3(0, 0, 3), CombatTweak.data().hitscan_mask)
	var hit: Dictionary = s.get_world_3d().direct_space_state.intersect_ray(q)
	assert_true(not hit.is_empty() and hit.get("collider") == s, "a dropped shield still blocks bullets")


func test_l4_5_specials_take_position_behind_bulwark() -> void:
	var c: CrewController = await _loud()
	var bw: NpcBase = ACombatSpecials.spawn(_rt, "bulwark", c.global_position + Vector3(0, 0, -10), Vector3(0, 0, 1))
	var med: NpcBase = ACombatSpecials.spawn(_rt, "corpsman", c.global_position + Vector3(3, 0, -14))
	for n: String in ["Brain", "Motor"]:
		bw.get_node(n).set_physics_process(false)
	await wait_physics_frames(2)
	var spot: Vector3 = PoliceSpecialKit.spot_behind_bulwark(med)
	assert_true(spot != Vector3.INF, "allied Bulwark within the join distance")
	assert_true(spot.z < bw.global_position.z, "the spot is behind the shield (away from where it faces)")
	var mb: CorpsmanBrain = med.get_node("Brain") as CorpsmanBrain
	var behind: bool = await wait_until(func() -> bool: return _flat(med.global_position - spot) < 1.0, 8.0)
	assert_true(behind, "Corpsman moves behind the Bulwark (mode %s)" % mb.mode)
	assert_eq(PoliceSpecialKit.limit_key(&"enemy.bulwark"), &"enemy.bulwark")


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _shield_hit(s: BulwarkShield, amount: float) -> Dictionary:
	var info: Dictionary = Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"weapon.test",
		s.global_position, Vector3(0, 0, -1), 0)
	return s.take_hit(info, 0)


## Stagger (shock-and-awe-like): a heavy shield hit or an explosion drops the guard briefly (no shield
## collision, frontal hits reach the body), no fire / move; cooldown; Aegis shields never stagger.
func test_l4_5_heavy_hit_and_explosion_stagger() -> void:
	await _loud()
	var bw: NpcBase = ACombatSpecials.spawn(_rt, "bulwark", Vector3(0, 0.05, -8), Vector3(0, 0, 1))
	var b: BulwarkBrain = bw.get_node("Brain") as BulwarkBrain
	var st: HeavySpecialTweak = b.special_tweak.duplicate() as HeavySpecialTweak
	st.bulwark_stagger_s = 0.6
	st.bulwark_stagger_cooldown_s = 0.5
	b.special_tweak = st
	await wait_physics_frames(3)
	var s: BulwarkShield = b.shield
	_shield_hit(s, st.bulwark_stagger_hit_damage * 0.5)
	assert_false(b.is_staggered(), "light hits do not stagger")
	var r: Dictionary = _shield_hit(s, st.bulwark_stagger_hit_damage)
	assert_true(bool(r["blocked_by_shield"]), "the staggering hit itself is blocked")
	assert_true(b.is_staggered() and s.guard_down, "heavy hit staggers")
	assert_eq(s.collision_layer, 0, "guard down: the shield does not block")
	assert_eq(b.anim_hint, &"hit_react")
	await wait_physics_frames(2)
	assert_false(b.wants_to_fire, "no fire while staggered")
	var where: Vector3 = s.global_position
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		where + Vector3(0, 0, 3), where - Vector3(0, 0, 3), CombatTweak.data().hitscan_mask)
	q.collide_with_areas = true
	var hit: Dictionary = s.get_world_3d().direct_space_state.intersect_ray(q)
	assert_true(hit.is_empty() or hit.get("collider") != s, "frontal shots get past the lowered shield")
	assert_false(b.stagger(), "no stagger while staggered")
	var up: bool = await wait_until(func() -> bool: return not b.is_staggered(), 2.0)
	assert_true(up and not s.guard_down, "guard back up")
	assert_eq(s.collision_layer, 1 << 1, "blocks again")
	_shield_hit(s, st.bulwark_stagger_hit_damage * 2.0)
	assert_eq(b.staggers, 1, "cooldown")
	await wait_seconds(st.bulwark_stagger_cooldown_s + 0.1)
	ACombatSpecials.hit(bw, 30.0, Enums.HitZone.BODY, Vector3.INF, Enums.DamageType.EXPLOSION)
	assert_eq(b.staggers, 2, "an explosion staggers")
	var up2: bool = await wait_until(func() -> bool: return not b.is_staggered(), 2.0)
	assert_true(up2)
	await wait_seconds(st.bulwark_stagger_cooldown_s + 0.1)
	bw.set_meta(AegisCaptain.META_NO_FLINCH, true)
	_shield_hit(s, st.bulwark_stagger_hit_damage * 2.0)
	assert_eq(b.staggers, 2, "Aegis (no flinch) shields never stagger")


func test_l4_5_dies_while_staggered_drops_a_blocking_shield() -> void:
	var bw: NpcBase = ACombatSpecials.spawn(_rt, "bulwark", Vector3(0, 0.05, -8), Vector3(0, 0, 1))
	await wait_physics_frames(3)
	var b: BulwarkBrain = bw.get_node("Brain") as BulwarkBrain
	assert_true(b.stagger(), "staggered")
	bw.die({}, 0)
	await wait_physics_frames(3)
	assert_true(b.shield.dropped and not b.shield.guard_down, "dropped with the guard up")
	assert_eq(b.shield.collision_layer, 1 << 1, "the dropped shield blocks")
