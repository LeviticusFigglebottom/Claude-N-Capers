## D-163 VFX review (ENV C): Sicario's smoke cloud and the Tag Team tether in a plain test yard, three frames
## (0.5 s fade-in, 4 s hold, 9 s fade-out). Windowed only:
##   xvfb-run -a /opt/godot/godot --path game [--rendering-driver opengl3] res://world/tools/vfx_d163_review.tscn \
##     -- --out=<path prefix> [--radius=4]
extends Node3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = preload("res://world/tools/validate_level.gd").parse_args(OS.get_cmdline_user_args())
	var radius: float = float(args.get("radius", "4"))
	var root: Node3D = Node3D.new()
	add_child(root)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.1, 0.1, 0.12)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	root.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(40, 40)
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color(0.22, 0.2, 0.18)  # dark ground and red crates: the grey cloud must read against both
	pm.material = fm
	floor_mi.mesh = pm
	root.add_child(floor_mi)
	for x: int in [-4, 0, 4]:
		var crate: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		var cm: StandardMaterial3D = StandardMaterial3D.new()
		cm.albedo_color = Color(0.7, 0.15, 0.1)
		bm.material = cm
		crate.mesh = bm
		crate.position = Vector3(x, 0.5, -2)
		root.add_child(crate)
	var d: VfxDirector = VfxDirector.new()
	d.listen_to_event_bus = false
	d.use_game_settings = false
	d.play_impact_cues = false
	d.auto_advance = false
	root.add_child(d)
	var a: Node3D = Node3D.new()
	var b: Node3D = Node3D.new()
	a.position = Vector3(-3, 0, 6)
	b.position = Vector3(3, 0, 7)
	root.add_child(a)
	root.add_child(b)
	for n: Node3D in [a, b]:
		var cap: MeshInstance3D = MeshInstance3D.new()
		cap.mesh = CapsuleMesh.new()
		cap.position = Vector3(0, 0.9, 0)
		n.add_child(cap)
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0, 1.8, 11)
	root.add_child(cam)
	cam.look_at(Vector3(0, 1.4, 0))
	cam.make_current()
	d.smoke.fire(Vector3(0, 0, -2), radius, 10.0)
	d.tethers.link(Vector2i(0, 1), a, b)
	var out: String = String(args.get("out", "user://vfx_d163"))
	var t: float = 0.0
	for shot: float in [0.5, 4.0, 9.0]:
		while t < shot:
			await get_tree().process_frame
			t += 0.25
			d.advance(0.25)
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_jpg("%s_%02d.jpg" % [out, int(shot * 10.0)])
	get_tree().quit()
