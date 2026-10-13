## PO-5.7 (D-089) for specials: Bulwark, Aegis, Wrecker (all weapon variants), Stinger, Phantom, Corpsman,
## Longshot and Brandt wear their ENV D characters (characters.md; faction variant v1.6), keep their
## contract nodes (Wrecker Faceplate / Visor, Phantom Goggles, Longshot LaserOrigin) and their hitboxes,
## and the Bulwark carries its character's own shield in front, its body at the carry offset.
extends TestCase

const SPECIALS: Dictionary = {
	"bulwark": "bulwark", "aegis": "bulwark_aegis", "wrecker": "wrecker", "wrecker_s": "wrecker",
	"wrecker_b": "wrecker", "wrecker_g": "wrecker", "wrecker_m": "wrecker", "stinger": "stinger",
	"phantom": "phantom", "corpsman": "corpsman", "longshot": "longshot", "brandt": "brandt",
}
const CONTRACT_NODES: Dictionary = {
	"wrecker": ["Faceplate", "Visor"], "phantom": ["Goggles"], "longshot": ["LaserOrigin"],
}

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await ACombatSpecials.launch(self)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_specials_wear_their_characters() -> void:
	var x: float = -12.0
	for id: String in SPECIALS:
		var npc: NpcBase = ACombatSpecials.spawn(_rt, id, Vector3(x, 0.05, -10))
		x += 2.0
		var want: String = NpcVisuals.scene_path(String(SPECIALS[id]))
		assert_true(npc.visual_scene != null and npc.visual_scene.resource_path == want,
			"%s wears %s (got %s)" % [id, want, npc.visual_scene.resource_path if npc.visual_scene != null else "capsule"])
		assert_true(AnimDriver.find_player(npc) != null, "%s: animated character" % id)
		assert_true(npc.get_node_or_null("Hitboxes/Head") != null and npc.get_node_or_null("Hitboxes/Body") != null,
			"%s: hitboxes" % id)
		for nm: String in CONTRACT_NODES.get(id, []):
			assert_true(npc.get_node("Visual").find_child(nm, true, false) != null, "%s: %s node" % [id, nm])
	await wait_physics_frames(2)


func test_faction_variant_special_and_its_shield() -> void:
	var def: EnemyDef = ACombatSpecials.def("bulwark").duplicate() as EnemyDef
	def.params = def.params.duplicate()
	def.params["visual_variant"] = "frd"
	var bw: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -8)), {"enemy_def": def})
	assert_eq(bw.visual_scene.resource_path, NpcVisuals.scene_path("bulwark", "frd"), "bulwark_frd character")
	var own: PackedScene = NpcVisuals.prop_scene(bw, "shield")
	assert_true(own != null and own.resource_path.ends_with("bulwark_frd/bulwark_frd_shield.tscn"),
		"characters.md v1.6: bulwark_<v>/bulwark_<v>_shield.tscn")
	await wait_physics_frames(3)
	var s: BulwarkShield = (bw.get_node("Brain") as BulwarkBrain).shield
	assert_true(s != null and s.character_geometry, "carries its character's shield")


func test_bulwark_character_shield_in_front_and_blocking() -> void:
	var bw: NpcBase = ACombatSpecials.spawn(_rt, "bulwark", Vector3(0, 0.05, -8), Vector3(0, 0, 1))
	await wait_physics_frames(3)
	var s: BulwarkShield = (bw.get_node("Brain") as BulwarkBrain).shield
	var tw: HeavySpecialTweak = HeavySpecialTweak.data()
	assert_true(s.character_geometry, "the character's own shield geometry")
	assert_true(s.get_node_or_null("Collision") is CollisionShape3D and s.get_node_or_null("Visual") != null,
		"Collision + Visual")
	assert_true(s.position.is_equal_approx(tw.bulwark_grip_offset), "body at the grip offset")
	# Several frames of animation: the body never leaves the carry offset (gameplay ignores animation).
	await wait_physics_frames(20)
	assert_true(s.position.is_equal_approx(tw.bulwark_grip_offset), "the body stays put while animating")
	var vis: Node3D = s.get_node("Visual") as Node3D
	assert_true(bw.to_local(vis.global_position).z < -0.15, "the shield visual is in front")
	# A frontal round at chest height is stopped by the shield.
	var chest: Vector3 = bw.global_position + Vector3(0, 1.1, 0)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		chest + Vector3(0, 0, 4), chest, CombatTweak.data().hitscan_mask)
	q.collide_with_areas = true
	var hit: Dictionary = s.get_world_3d().direct_space_state.intersect_ray(q)
	assert_true(not hit.is_empty() and hit.get("collider") == s, "frontal chest shot hits the shield first")
