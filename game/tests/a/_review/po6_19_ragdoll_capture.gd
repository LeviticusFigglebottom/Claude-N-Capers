## PO6-19 windowed review (not a test): NpcRagdoll on Security Officer guards, captured to contact sheets.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 960x540 res://tests/a/_review/po6_19_ragdoll_capture.tscn -- --out=<dir>
## Writes <out>/po6_19_shotgun.png (point-blank shotgun: 0 / 0.15 / 0.4 / 1 / 3.5 s), po6_19_grenade.png (a frag
## among four guards), po6_19_corpse.png (a frozen corpse shot three times: red dots = blood_hit points) and
## po6_19_pistol.png (a pistol kill at range: death clip, then the settle) and prints a summary. Owner: ENV A.
extends Node3D

const SCENE: String = "res://world/characters/security_officer/security_officer.tscn"
const TILE: Vector2i = Vector2i(480, 270)

var _out: String = "user://po6_19"
var _cam: Camera3D = null
var _blood: Array[Vector3] = []
var _floor: StaticBody3D = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	EventBus.blood_hit.connect(func(_v: int, p: Vector3, _d: Vector3, _n: Vector3, _s: float, _h: bool, _e: Vector3,
			_k: StringName) -> void: _blood.append(p))
	_stage()
	_run.call_deferred()


func _run() -> void:
	await _shotgun_scene()
	await _grenade_scene()
	await _corpse_scene()
	await _pistol_scene()
	print("po6_19_capture: done -> %s" % _out)
	get_tree().quit(0)


func _stage() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.63, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50.0, 150.0, 0.0)
	key.shadow_enabled = true
	add_child(key)
	_floor = StaticBody3D.new()
	_floor.collision_layer = 1
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	_floor.add_child(col)
	var vis: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	vis.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.46, 0.48)
	vis.material_override = mat
	_floor.add_child(vis)
	add_child(_floor)
	# 1 m grid marks along Z so the throw distance reads on the sheet.
	for z: int in range(-2, 6):
		for x: int in [-40, 0, 40]:
			var m: MeshInstance3D = MeshInstance3D.new()
			var b: BoxMesh = BoxMesh.new()
			b.size = Vector3(1.6, 0.005, 0.03)
			m.mesh = b
			m.position = Vector3(x, 0.003, z)
			add_child(m)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true


func _npc(pos: Vector3, yaw: float = 0.0) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = &"guard"
	npc.visual_scene = load(SCENE) as PackedScene
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	npc.add_child(visual)
	npc.position = pos
	npc.rotation.y = yaw
	add_child(npc)
	npc.max_health = 100.0
	npc.health = 100.0
	npc.alert_state = Enums.AlertState.COMBAT
	return npc


func _look(eye: Vector3, target: Vector3) -> void:
	_cam.global_transform = Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP).translated(eye)


func _wait(seconds: float) -> void:
	for i: int in range(maxi(roundi(seconds * Engine.physics_ticks_per_second), 1)):
		await get_tree().physics_frame


func _grab() -> Image:
	for i: int in range(2):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(TILE.x, TILE.y)
	return img


func _save(tiles: Array[Image], file: String) -> void:
	var sheet: Image = Image.create(TILE.x * tiles.size(), TILE.y, false, Image.FORMAT_RGBA8)
	for i: int in range(tiles.size()):
		sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * i, 0))
	var path: String = _out.path_join(file)
	print("po6_19_capture: %s %s" % [path, error_string(sheet.save_png(path))])


func _shot(npc: NpcBase, weapon: StringName, pellets: int, at: Vector3, dir: Vector3, range_m: float) -> void:
	for i: int in pellets:
		var d: Dictionary = Damage.info(30.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, weapon,
			at + Vector3(0.03 * (i % 3), 0.03 * (i / 3), 0), dir)
		d["range_m"] = range_m
		npc.take_hit(d)


static func _hips(npc: NpcBase) -> Vector3:
	var rd: NpcRagdoll = NpcRagdoll.of(npc)
	return rd.bodies[rd._body_index(NpcRagdoll.HIPS_BODY)].global_position if rd != null else npc.global_position


func _shotgun_scene() -> void:
	var g: NpcBase = _npc(Vector3(0, 0, 0))
	await _wait(0.5)
	_look(Vector3(4.5, 1.6, 1.2), Vector3(0, 0.6, 1.2))
	var tiles: Array[Image] = [await _grab()]
	_shot(g, &"weapon.brute_12", 10, Vector3(0, 1.3, -0.1), Vector3(0, 0, 1), 2.0)
	for t: float in [0.15, 0.25, 0.6, 2.5]:
		await _wait(t)
		tiles.append(await _grab())
	_save(tiles, "po6_19_shotgun.png")
	print("po6_19_capture: shotgun hips moved %.2f m, phase %d" % [_hips(g).z, NpcRagdoll.of(g).phase])


func _grenade_scene() -> void:
	var c: Vector3 = Vector3(40, 0, 0)
	var group: Array[NpcBase] = []
	for i: int in 4:
		var a: float = TAU * i / 4.0 + 0.4
		group.append(_npc(c + Vector3(cos(a), 0, sin(a)) * 1.6, -a))
	await _wait(0.5)
	_look(c + Vector3(0, 6.5, 6.0), c)
	var tiles: Array[Image] = [await _grab()]
	Explosion.apply(_floor, c + Vector3(0, 0.3, 0), 5.0, 1000.0, 0, &"weapon.frag")
	for t: float in [0.15, 0.3, 0.8, 2.5]:
		await _wait(t)
		tiles.append(await _grab())
	_save(tiles, "po6_19_grenade.png")
	var out: Array[String] = []
	for n: NpcBase in group:
		out.append("%.2f" % (_hips(n) - c).length())
	print("po6_19_capture: grenade hips distance from the blast %s" % ", ".join(out))


func _corpse_scene() -> void:
	var g: NpcBase = _npc(Vector3(-40, 0, 0))
	await _wait(0.5)
	_shot(g, &"weapon.brute_12", 10, Vector3(-40, 1.3, -0.1), Vector3(0, 0, 1), 2.0)
	await _wait(RagdollTweak.data().settle_s + 0.3)
	var rd: NpcRagdoll = NpcRagdoll.of(g)
	_look(Vector3(-37.0, 2.2, 1.5), Vector3(-40, 0.1, 1.2))
	var tiles: Array[Image] = [await _grab()]
	_blood.clear()
	var hb: Node3D = g.get_node(NpcBase.CORPSE_HITBOX) as Node3D
	for i: int in 3:
		var target: Vector3 = hb.global_position + hb.global_basis.z * (0.5 - 0.5 * i)
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(-37.0, 1.6, 1.5), target
			+ (target - Vector3(-37.0, 1.6, 1.5)).normalized(), CombatTweak.data().hitscan_mask)
		q.collide_with_areas = true
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			continue
		var p: Vector3 = hit["position"]
		var d: Dictionary = Damage.info(40.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"weapon.corsair_ar", p,
			(p - Vector3(-37.0, 1.6, 1.5)).normalized())
		d["range_m"] = 3.0
		g.take_hit(d)
		_dot(p)
		await _wait(0.1)
		tiles.append(await _grab())
	await _wait(1.3)
	tiles.append(await _grab())
	_save(tiles, "po6_19_corpse.png")
	print("po6_19_capture: corpse shots -> %d blood_hit, freezes %d, phase %d" % [_blood.size(), rd.freezes, rd.phase])


func _pistol_scene() -> void:
	var g: NpcBase = _npc(Vector3(0, 0, 40))
	await _wait(0.5)
	_look(Vector3(4.0, 1.6, 41.0), Vector3(0, 0.7, 40.6))
	var tiles: Array[Image] = [await _grab()]
	_shot(g, &"weapon.kestrel_p9", 1, Vector3(0, 1.5, 39.9), Vector3(0, 0, 1), 20.0)
	g.take_hit(Damage.info(500.0, Enums.DamageType.BULLET, Enums.HitZone.HEAD, &"weapon.kestrel_p9",
		Vector3(0, 1.65, 39.9), Vector3(0, 0, 1)))
	for t: float in [0.3, 0.6, 1.2, 2.5]:
		await _wait(t)
		tiles.append(await _grab())
	_save(tiles, "po6_19_pistol.png")
	var rd: NpcRagdoll = NpcRagdoll.of(g)
	print("po6_19_capture: pistol death clip %s, phase %d, freezes %d" % [AnimDriver.of(g).clip, rd.phase, rd.freezes])


func _dot(p: Vector3) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var s: SphereMesh = SphereMesh.new()
	s.radius = 0.04
	s.height = 0.08
	m.mesh = s
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.05, 0.05)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	m.material_override = mat
	m.position = p
	add_child(m)
