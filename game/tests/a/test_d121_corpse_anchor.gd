## D-121: the deterministic server corpse anchor (CorpseAnchor). The root and the corpse hitbox sit on the
## pose-at-death root + flat push x RagdollTweak.anchor_offset_m (strong kills: anchor_strong_offset_m), short
## of walls, on the floor; the ragdoll moves the visual only. The anchors of a seeded set of kills replay in a
## second Godot process and in the same process after other physics activity (where ragdolls diverged, DET).
extends TestCase

const SCENE: String = "res://world/characters/security_officer/security_officer.tscn"

var _nodes: Array[Node] = []
var _floor: StaticBody3D = null


func before_each() -> void:
	_floor = StaticBody3D.new()
	_floor.collision_layer = 1
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	_floor.add_child(col)
	add_child(_floor)


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	if is_instance_valid(_floor):
		_floor.queue_free()
	await wait_physics_frames(2)


func _npc(pos: Vector3, visual: bool = true) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = &"guard"
	if visual:
		npc.visual_scene = load(SCENE) as PackedScene
	var v: Node3D = Node3D.new()
	v.name = "Visual"
	npc.add_child(v)
	npc.position = pos
	add_child(npc)
	_nodes.append(npc)
	npc.max_health = 100.0
	npc.health = 100.0
	npc.alert_state = Enums.AlertState.COMBAT
	return npc


static func _pistol(at: Vector3, dir: Vector3) -> Dictionary:
	var d: Dictionary = Damage.info(500.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"weapon.kestrel_p9", at, dir)
	d["range_m"] = 20.0
	return d


func test_d121_anchor_is_root_plus_push_on_the_floor() -> void:
	var tw: RagdollTweak = RagdollTweak.data()
	var npc: NpcBase = _npc(Vector3(-80, 0, 0))
	await wait_physics_frames(3)
	var vis_before: Vector3 = npc.visual_root.global_position
	npc.take_hit(_pistol(npc.global_position + Vector3(0, 1.3, 0), Vector3(1, -0.2, 0)))
	assert_false(npc.alive, "killed")
	var want: Vector3 = Vector3(-80.0 + tw.anchor_offset_m, 0.0, 0.0)
	assert_true(npc.corpse_anchor.is_equal_approx(want), "anchor %s (want %s)" % [npc.corpse_anchor, want])
	assert_true(npc.global_position.is_equal_approx(want), "root on the anchor")
	assert_true(npc.visual_root.global_position.is_equal_approx(vis_before), "the visual did not jump")
	var hb: Hitbox = npc.get_node(NpcBase.CORPSE_HITBOX) as Hitbox
	assert_near(hb.global_position.x, want.x, 0.001, "corpse hitbox centred on the anchor")
	assert_near(absf(hb.global_basis.z.normalized().x), 1.0, 0.001, "lying along the push")
	await wait_physics_frames(roundi((tw.anim_wait_max_s + tw.settle_after_anim_s + tw.settle_s) * Engine.physics_ticks_per_second))
	assert_true(npc.global_position.is_equal_approx(want), "the ragdoll never moved the root (%s)" % npc.global_position)
	assert_near(hb.global_position.x, want.x, 0.001, "nor the hitbox")


func test_d121_strong_kills_wall_clamp_and_fallback_direction() -> void:
	var tw: RagdollTweak = RagdollTweak.data()
	var shot: NpcBase = _npc(Vector3(-80, 0, 20), false)
	var walled: NpcBase = _npc(Vector3(-80, 0, 40), false)
	var nodir: NpcBase = _npc(Vector3(-80, 0, 60), false)
	var wall: CollisionShape3D = CollisionShape3D.new()
	var wb: BoxShape3D = BoxShape3D.new()
	wb.size = Vector3(4.0, 3.0, 0.2)
	wall.shape = wb
	wall.position = Vector3(-80, 1.5, 40.5)
	_floor.add_child(wall)
	await wait_physics_frames(3)
	for k: int in 10:
		var d: Dictionary = Damage.info(30.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"weapon.brute_12",
			shot.global_position + Vector3(0, 1.3, 0), Vector3(0, 0, -1))
		d["range_m"] = 1.0
		shot.take_hit(d)
	assert_true(shot.corpse_anchor.is_equal_approx(Vector3(-80, 0, 20.0 - tw.anchor_strong_offset_m)),
		"point-blank shotgun: strong offset (%s)" % shot.corpse_anchor)
	walled.take_hit(_pistol(walled.global_position + Vector3(0, 1.3, 0), Vector3(0, 0, 1)))
	var reach: float = 0.4 - tw.anchor_wall_margin_m  # the wall's near face is 0.4 m away
	assert_near(walled.corpse_anchor.z, 40.0 + reach, 0.02, "stopped short of the wall (%s)" % walled.corpse_anchor)
	nodir.die({}, 0)
	var fwd: Vector3 = -nodir.global_basis.z
	assert_true(nodir.corpse_anchor.is_equal_approx(Vector3(-80, 0, 60) + fwd * tw.anchor_offset_m),
		"no hit direction: a fall forward (%s)" % nodir.corpse_anchor)


func test_d121_client_takes_the_replicated_anchor() -> void:
	var server: NpcBase = _npc(Vector3(-80, 0, 80))
	var client: NpcBase = _npc(Vector3(-80, 0, 80))
	await wait_physics_frames(3)
	server.take_hit(_pistol(server.global_position + Vector3(0, 1.3, 0), Vector3(0, 0, 1)))
	var st: Dictionary = NetEntityCodec.state_of(server)
	assert_true(st.has("ca"), "the anchor replicates")
	client.alive = false  # a replica's die() (no anchor of its own; clients only apply "ca")
	var vis: Vector3 = client.visual_root.global_position
	NetEntityCodec.apply_xform(client, Transform3D(Basis.IDENTITY, server.global_position))
	assert_true(client.global_position.is_equal_approx(server.global_position), "the dead root follows the server")
	assert_true(client.visual_root.global_position.is_equal_approx(vis), "without dragging the visual")
	var ca: Array = st["ca"] as Array
	CorpseAnchor.apply(client, ca[0] as Vector3, ca[1] as Vector3)
	var hs: Hitbox = server.get_node(NpcBase.CORPSE_HITBOX) as Hitbox
	var hc: Hitbox = client.get_node(NpcBase.CORPSE_HITBOX) as Hitbox
	assert_true(hc.global_transform.is_equal_approx(hs.global_transform), "same corpse hitbox on the client")
	NetEntityCodec.apply_xform(client, Transform3D(Basis.IDENTITY, Vector3(5, 0, 5)))
	assert_true(client.global_position.is_equal_approx(server.global_position), "the anchor owns the corpse root")


## Same process: the probe, then unrelated ragdoll / bag physics, then the probe again: anchors identical.
func test_d121_anchors_replay_after_other_physics_in_process() -> void:
	var a: Dictionary = await D121AnchorProbe.run(self)
	await _other_physics()
	var b: Dictionary = await D121AnchorProbe.run(self)
	print("[D121] anchors:\n%s\n[D121] hips run1:\n%s\n[D121] hips run2:\n%s" % [a["anchors"], a["hips"], b["hips"]])
	assert_eq(String(b["anchors"]), String(a["anchors"]), "anchors replay in-process")
	assert_false(String(a["anchors"]).contains("alive=true"), "every probe NPC died")


## A second Godot process runs the probe scene and writes its anchors; they equal this process's.
func test_d121_anchors_replay_in_a_second_process() -> void:
	var out: String = OS.get_user_data_dir().path_join("d121_probe_%d.txt" % OS.get_process_id())
	var args: PackedStringArray = PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"res://tests/a/d121_anchor_probe.tscn", "--", "--d121-out=" + out])
	var log_lines: Array = []
	var rc: int = OS.execute(OS.get_executable_path(), args, log_lines, true)
	assert_eq(rc, 0, "probe process exit code")
	var f: FileAccess = FileAccess.open(out, FileAccess.READ)
	assert_true(f != null, "probe output %s" % out)
	if f == null:
		return
	var other: String = f.get_as_text()
	f.close()
	DirAccess.remove_absolute(out)
	var here: Dictionary = await D121AnchorProbe.run(self)
	var other_anchors: String = other.get_slice("\n--hips--\n", 0)
	assert_eq(other_anchors, String(here["anchors"]), "anchors replay across processes")


## Unrelated physics: point-blank shotgun ragdolls and thrown bags, then cleaned up.
func _other_physics() -> void:
	var n: Array[NpcBase] = []
	for i: int in 3:
		n.append(_npc(Vector3(-120.0 + 2.0 * i, 0.0, -50.0)))
	var bag: LootBag = (load("res://systems/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	add_child(bag)
	_nodes.append(bag)
	bag.global_position = Vector3(-120.0, 1.5, -40.0)
	await wait_physics_frames(3)
	bag.release(bag.global_position, Vector3(2.0, 3.0, 1.0), true)
	for x: NpcBase in n:
		for k: int in 10:
			var d: Dictionary = Damage.info(30.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"weapon.brute_12",
				x.global_position + Vector3(0.02 * k, 1.3, 0), Vector3(0.3, 0, 1).normalized())
			d["range_m"] = 1.0
			x.take_hit(d)
	await wait_physics_frames(roundi(2.0 * Engine.physics_ticks_per_second))
	for x: Node in n:
		x.queue_free()
	bag.queue_free()
	await wait_physics_frames(2)


func test_d121_blast_on_a_corpse_moves_the_anchor_outward() -> void:
	var npc: NpcBase = _npc(Vector3(-80, 0, 100))
	await wait_physics_frames(3)
	npc.take_hit(_pistol(npc.global_position + Vector3(0, 1.3, 0), Vector3(0, 0, 1)))
	var before: Vector3 = npc.corpse_anchor
	await wait_physics_frames(2)
	var c: Vector3 = before + Vector3(-1.0, 0.3, 0.0)
	Explosion.apply(_floor, c, 4.0, 1000.0, 0, &"weapon.frag")
	var moved: Vector3 = npc.corpse_anchor - before
	assert_true(moved.x > 0.1 and absf(moved.z) < 0.01, "pushed away from the blast (%s)" % moved)
	assert_true(npc.global_position.is_equal_approx(npc.corpse_anchor), "root follows the anchor")
