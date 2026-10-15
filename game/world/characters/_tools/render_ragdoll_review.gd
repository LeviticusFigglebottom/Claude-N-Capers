## PO6-19: windowed review of the physical-bones ragdoll (ragdoll_builder.gd). Owner: ENV D.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy \
##     --rendering-driver opengl3 --path game --script res://world/characters/_tools/render_ragdoll_review.gd
##
## A Security Officer stands on a floor playing `idle`; the ragdoll is started the way ENV A will
## (RAGDOLL.md: `active = true`, `physical_bones_start_simulation()`) and the chest gets a 150 N s impulse
## backwards (a point-blank shotgun hit). Writes to res://assets/characters/_review/:
## * ragdoll_guard.png: before / mid-fall (0.4 s) / settled (3 s), two views of the settled body.
## * ragdoll_shapes.png: the settled body with the ragdoll's collision shapes drawn over it.
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const OUT_DIR: String = "res://assets/characters/_review/"
const CHAR: String = "char_security_officer"
const IMPULSE: Vector3 = Vector3(0.0, 0.0, 150.0)
const TILE: Vector2i = Vector2i(640, 480)
const SHAPE_COLOUR: Color = Color(1.0, 0.45, 0.1, 0.55)

var _vp: SubViewport
var _cam: Camera3D
var _errors: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_ragdoll_review: --headless has no renderer; run under xvfb-run")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_stage()
	var guard: Node3D = (load(Spec.scene_path(CHAR)) as PackedScene).instantiate() as Node3D
	CrowdLod.force_level(guard, false)
	_vp.add_child(guard)
	var player: AnimationPlayer = guard.get_node("AnimationPlayer") as AnimationPlayer
	player.play("humanoid/idle")
	var sim: PhysicalBoneSimulator3D = guard.get_node("Skeleton3D/" + Spec.RAGDOLL_NODE) as PhysicalBoneSimulator3D
	var side: Transform3D = _view(Vector3(2.6, 1.5, -1.6), Vector3(0.0, 0.6, 0.4))
	var tiles: Array[Image] = [await _grab(side)]
	player.pause()
	sim.active = true
	sim.physical_bones_start_simulation()
	await physics_frame
	(sim.get_node("Chest") as PhysicalBone3D).apply_central_impulse(IMPULSE)
	await _physics(0.4)
	tiles.append(await _grab(side))
	await _physics(2.6)
	tiles.append(await _grab(side))
	tiles.append(await _grab(_view(Vector3(0.0, 3.2, 0.7), Vector3(0.0, 0.0, 0.7), Vector3(0.0, 0.0, -1.0))))
	_save(_sheet(tiles), "ragdoll_guard.png")
	for pb: Node in sim.get_children():
		for c: Node in pb.get_children():
			if c is CollisionShape3D:
				c.add_child(_shape_mesh((c as CollisionShape3D).shape))
	var shapes: Array[Image] = [await _grab(side),
		await _grab(_view(Vector3(0.0, 3.2, 0.7), Vector3(0.0, 0.0, 0.7), Vector3(0.0, 0.0, -1.0)))]
	_save(_sheet(shapes), "ragdoll_shapes.png")
	var hips: Vector3 = (sim.get_node("Hips") as Node3D).global_position
	print("render_ragdoll_review: settled hips at %s, %d error(s)" % [hips, _errors])
	quit(1 if _errors > 0 else 0)


func _stage() -> void:
	_vp = SubViewport.new()
	_vp.size = TILE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.63, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment.ambient_light_energy = 0.6
	_vp.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50.0, 150.0, 0.0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	_vp.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -40.0, 0.0)
	fill.light_energy = 0.4
	_vp.add_child(fill)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1  # world_static
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(col)
	var vis: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	vis.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.48, 0.5)
	vis.material_override = mat
	floor_body.add_child(vis)
	_vp.add_child(floor_body)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_vp.add_child(_cam)
	_cam.current = true


func _view(eye: Vector3, target: Vector3, up: Vector3 = Vector3.UP) -> Transform3D:
	return Transform3D.IDENTITY.looking_at(target - eye, up).translated(eye)


func _physics(seconds: float) -> void:
	for i: int in range(roundi(seconds * Engine.physics_ticks_per_second)):
		await physics_frame


func _grab(view: Transform3D) -> Image:
	_cam.global_transform = view
	for i: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _shape_mesh(shape: Shape3D) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	if shape is BoxShape3D:
		var box: BoxMesh = BoxMesh.new()
		box.size = (shape as BoxShape3D).size
		mi.mesh = box
	elif shape is CapsuleShape3D:
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = (shape as CapsuleShape3D).radius
		cap.height = (shape as CapsuleShape3D).height
		mi.mesh = cap
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = SHAPE_COLOUR
	mi.material_override = mat
	return mi


func _sheet(tiles: Array[Image]) -> Image:
	var sheet: Image = Image.create(TILE.x * tiles.size(), TILE.y, false, Image.FORMAT_RGBA8)
	for i: int in range(tiles.size()):
		sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * i, 0))
	return sheet


func _save(img: Image, file: String) -> void:
	var err: Error = img.save_png(OUT_DIR + file)
	if err != OK:
		_errors += 1
		push_error("render_ragdoll_review: could not save %s (%s)" % [file, error_string(err)])
	else:
		print("render_ragdoll_review: wrote %s%s" % [OUT_DIR, file])
