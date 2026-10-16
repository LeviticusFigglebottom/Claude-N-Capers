## D-121 probe: a seeded set of kills in a small walled arena; returns (or, run as a scene, writes) the corpse
## anchors / hitboxes (gameplay, must replay anywhere) and the ragdoll hips (cosmetic, may not). Owner: ENV A.
## Scene use (a second process): godot --headless --path game res://tests/a/d121_anchor_probe.tscn -- --d121-out=<file>
class_name D121AnchorProbe
extends Node

const SCENE: String = "res://world/characters/security_officer/security_officer.tscn"
const KILLS: int = 8
const SEED: int = 121
## Arena origin, away from other tests' bodies.
const AT: Vector3 = Vector3(200.0, 0.0, 200.0)


func _ready() -> void:
	var out: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--d121-out="):
			out = a.trim_prefix("--d121-out=")
	if out == "":
		return
	var res: Dictionary = await run(self)
	var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	if f != null:
		f.store_string(String(res["anchors"]) + "\n--hips--\n" + String(res["hips"]))
		f.close()
	get_tree().quit(0)


static func _wait(host: Node, frames: int) -> void:
	for i: int in frames:
		await host.get_tree().physics_frame


## Build the arena under `host`, kill KILLS NPCs (seeded mix: far pistol, point-blank shotgun, sniper, melee,
## a grenade, one kill pushed into a wall), let the ragdolls settle and freeze, free everything.
## Returns {"anchors": String, "hips": String}.
static func run(host: Node) -> Dictionary:
	var root: Node3D = Node3D.new()
	root.name = "D121Arena"
	host.add_child(root)
	root.global_position = AT
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1
	var fc: CollisionShape3D = CollisionShape3D.new()
	fc.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(fc)
	var wall: CollisionShape3D = CollisionShape3D.new()
	var wb: BoxShape3D = BoxShape3D.new()
	wb.size = Vector3(30.0, 3.0, 0.3)
	wall.shape = wb
	wall.position = Vector3(0.0, 1.5, -2.0)
	floor_body.add_child(wall)
	root.add_child(floor_body)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()  # the probe's own fixed seed (test data)
	rng.seed = SEED
	var npcs: Array[NpcBase] = []
	for i: int in KILLS:
		var npc: NpcBase = NpcBase.new()
		npc.name = "Probe%d" % i
		npc.role = &"guard"
		npc.visual_scene = load(SCENE) as PackedScene
		var visual: Node3D = Node3D.new()
		visual.name = "Visual"
		npc.add_child(visual)
		npc.position = Vector3(-12.0 + 3.0 * i, 0.0, -0.8 if i == 3 else rng.randf_range(0.0, 2.0))
		npc.rotation.y = rng.randf_range(-PI, PI)
		root.add_child(npc)
		npc.max_health = 100.0
		npc.health = 100.0
		npc.alert_state = Enums.AlertState.COMBAT
		npcs.append(npc)
	await _wait(host, 3)
	for i: int in KILLS:
		var n: NpcBase = npcs[i]
		var a: float = rng.randf_range(-PI, PI)
		var dir: Vector3 = Vector3(sin(a), -0.1, cos(a)).normalized()
		if i == 3:
			dir = Vector3(0.0, 0.0, -1.0)  # into the wall 1.2 m behind
		var chest: Vector3 = n.global_position + Vector3(0.0, 1.3, 0.0)
		match i % 4:
			0:
				n.take_hit(_hit(500.0, &"weapon.kestrel_p9", chest, dir, 20.0))
			1:
				for k: int in 10:
					n.take_hit(_hit(30.0, &"weapon.brute_12", chest + Vector3(0.02 * k, 0.0, 0.0), dir, 1.0))
			2:
				n.take_hit(_hit(500.0, &"weapon.npc_sniper", chest, dir, 40.0))
			3:
				var m: Dictionary = Damage.info(500.0, Enums.DamageType.MELEE, Enums.HitZone.BODY, &"melee.fists", chest, dir)
				n.take_hit(m)
	await _wait(host, 2)
	Explosion.apply(floor_body, npcs[KILLS - 1].global_position + Vector3(1.0, 0.3, 0.5), 4.0, 1000.0, 0, &"weapon.frag")
	await _wait(host, roundi(5.0 * Engine.physics_ticks_per_second))
	var anchors: PackedStringArray = PackedStringArray()
	var hips: PackedStringArray = PackedStringArray()
	for n: NpcBase in npcs:
		var hb: Node3D = n.get_node_or_null(NpcBase.CORPSE_HITBOX) as Node3D
		var p: Vector3 = n.global_position - AT
		var h: Vector3 = (hb.global_position - AT) if hb != null else Vector3.INF
		anchors.append("%s alive=%s root=(%.4f,%.4f,%.4f) hb=(%.4f,%.4f,%.4f)" % [n.name, n.alive, p.x, p.y, p.z, h.x, h.y, h.z])
		var rd: NpcRagdoll = NpcRagdoll.of(n)
		var hp: Vector3 = Vector3.INF
		if rd != null:
			for pb: PhysicalBone3D in rd.bodies:
				if pb.name == NpcRagdoll.HIPS_BODY:
					hp = pb.global_position - AT
		hips.append("%s hips=(%.3f,%.3f,%.3f)" % [n.name, hp.x, hp.y, hp.z])
	root.queue_free()
	await _wait(host, 2)
	return {"anchors": "\n".join(anchors), "hips": "\n".join(hips)}


static func _hit(amount: float, weapon: StringName, at: Vector3, dir: Vector3, range_m: float) -> Dictionary:
	var d: Dictionary = Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, weapon, at, dir)
	d["range_m"] = range_m
	return d
