## PO-5.7: a Bulwark wearing its ENV D character plays the shield clip set while its guard is up
## (characters.md: shield_idle* blends with shield_walk frame 0; AnimTweak.shield_clips), so its left hand
## grips the shield and the shield Visual follows HandL/Socket in front. Guard down (stagger), death and
## rigs without the shield clips fall back to the normal clips.
extends TestCase

const ANIM_TESTS: String = "res://tests/a/test_anim_driver.gd"

var _rt: HeistRuntime = null
var _nodes: Array[Node] = []


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


func _bulwark() -> NpcBase:
	_rt = await ACombatSpecials.launch(self)
	var bw: NpcBase = ACombatSpecials.spawn(_rt, "bulwark", Vector3(0, 0.05, -8), Vector3(0, 0, 1))
	await wait_physics_frames(4)
	await wait_frames(2)
	return bw


func test_standing_bulwark_grips_the_shield() -> void:
	var bw: NpcBase = await _bulwark()
	var d: AnimDriver = AnimDriver.of(bw)
	var s: BulwarkShield = (bw.get_node("Brain") as BulwarkBrain).shield
	assert_true(d != null and d.player != null, "animated Bulwark character")
	assert_true(d.player.has_animation("humanoid/shield_idle"), "the rig has shield_idle")
	assert_true(d.carried_shield() == s and d.shield_up(), "the driver sees the raised shield")
	assert_true(String(d.clip).begins_with("shield_idle"), "standing Bulwark plays shield_idle (got %s)" % d.clip)
	await wait_physics_frames(2)
	await wait_frames(10)
	var rig_yaw: float = d.rig.rotation.y
	await wait_frames(10)
	assert_near(d.rig.rotation.y, rig_yaw, 0.001, "no turn-in-place spin after the spawn placement")
	assert_true(s.follow_grip(0.016), "real shield hold: the HandL/Socket pose is in front, facing forward")
	var vis: Node3D = s.get_node("Visual") as Node3D
	var socket: Node3D = AnimDriver.socket_of(bw, "HandL")
	assert_true(socket != null and s.grip_socket == socket, "grip socket found")
	assert_true(vis.global_transform.is_equal_approx(socket.global_transform.orthonormalized()),
		"the shield Visual follows the hand socket")
	assert_true(bw.to_local(vis.global_position).z < -BulwarkShield.GRIP_MIN_FRONT_M, "the Visual is in front")
	assert_true(s.position.is_equal_approx(HeavySpecialTweak.data().bulwark_grip_offset),
		"the body stays at the carry offset")
	# Aiming / firing in place keeps the shield idle (the hand never leaves the grip).
	var brain: BulwarkBrain = bw.get_node("Brain") as BulwarkBrain
	brain.anim_hint = &"aim"
	d.tick(0.016)
	assert_true(String(d.clip).begins_with("shield_idle"), "aiming Bulwark keeps shield_idle (got %s)" % d.clip)


func test_walk_bang_stagger_and_death() -> void:
	var bw: NpcBase = await _bulwark()
	var d: AnimDriver = AnimDriver.of(bw)
	var brain: BulwarkBrain = bw.get_node("Brain") as BulwarkBrain
	bw.velocity = Vector3(0, 0, 1.6)
	d.tick(0.016)
	assert_eq(d.clip, &"shield_walk", "moving Bulwark plays shield_walk")
	bw.velocity = Vector3(1.2, 0, 0)
	d.tick(0.016)
	assert_eq(d.clip, &"shield_walk", "a sideways shuffle keeps shield_walk")
	bw.velocity = Vector3.ZERO
	d.tick(0.016)
	assert_true(String(d.clip).begins_with("shield_idle"), "stopping returns to shield_idle")
	brain.anim_hint = &"shield_bang"
	d.tick(0.016)
	assert_eq(d.clip, &"shield_bang", "bang hint plays shield_bang")
	brain.anim_hint = &"idle"
	d.tick(0.016)
	# Stagger: guard down -> normal clips (hit_react), the Visual rests on the body; then re-raised.
	assert_true(brain.stagger(), "staggered")
	d.tick(0.016)
	assert_false(d.shield_up(), "guard down")
	assert_false(String(d.clip).begins_with("shield_"), "guard down: no shield clip (got %s)" % d.clip)
	assert_false(brain.shield.follow_grip(0.016), "guard down: the Visual rests on the body")
	await wait_seconds(HeavySpecialTweak.data().bulwark_stagger_s + 0.3)
	assert_true(d.shield_up(), "the brain re-raises the guard")
	d.tick(0.016)
	assert_true(String(d.clip).begins_with("shield_idle"), "guard up again: shield_idle (got %s)" % d.clip)
	# Death: death clip, then the shield is dropped (no carried shield).
	var s: BulwarkShield = brain.shield
	bw.die(Damage.info(9999.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"weapon.test", bw.global_position,
		Vector3(0, 0, -1), 0))
	d.tick(0.016)
	assert_true(String(d.clip).begins_with("death_"), "dead Bulwark plays a death clip (got %s)" % d.clip)
	await wait_physics_frames(3)
	assert_true(s.dropped and d.carried_shield() == null, "dropped shield is no longer carried")


## A rig without the shield clips keeps the normal clips; variants (`shield_idle_*`) are picked per body.
func test_fallback_and_variants() -> void:
	var anim_tests: GDScript = load(ANIM_TESTS) as GDScript
	var npc: NpcBase = NpcBase.new()
	npc.role = &"special"
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	var rig: Node3D = anim_tests.call(&"_test_rig") as Node3D
	visual.add_child(rig)
	npc.add_child(visual)
	add_child(npc)
	_nodes.append(npc)
	var tw: HeavySpecialTweak = HeavySpecialTweak.data()
	var shield: BulwarkShield = tw.bulwark_shield_scene.instantiate() as BulwarkShield
	shield.attach_to(npc, tw.bulwark_shield_offset)
	var d: AnimDriver = AnimDriver.ensure(npc)
	d.tick(0.016)
	assert_true(d.shield_up(), "shield carried, guard up")
	assert_eq(d.clip, &"idle", "no shield_idle in the rig: the normal idle plays")
	npc.velocity = Vector3(0, 0, -1.6)
	d.tick(0.016)
	assert_eq(d.clip, &"shield_walk", "the rig's shield_walk plays")
	var lib: AnimationLibrary = d.player.get_animation_library(AnimDriver.LIBRARY)
	for nm: String in ["shield_idle", "shield_idle_2", "shield_idler_x"]:
		var a: Animation = Animation.new()
		a.length = 3.6
		a.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(nm, a)
	d.bind()
	npc.velocity = Vector3.ZERO
	var seen: Dictionary = {}
	for id: int in [2, 3]:
		npc.net_id = id
		d.tick(0.016)
		seen[d.clip] = true
	assert_eq(seen.size(), 2, "two shield_idle variants spread over bodies")
	assert_true(seen.has(&"shield_idle") and seen.has(&"shield_idle_2"), "variants: shield_idle, shield_idle_2")
	shield.set_guard(false, tw.bulwark_stagger_shield_offset)
	d.tick(0.016)
	assert_eq(d.clip, &"idle", "guard down: normal idle")
