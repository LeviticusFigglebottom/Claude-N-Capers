## PO6-20 evidence: a guard-sized capsule behind a wall and one in the open, both with a live pager, plus one out of
## range. Windowed:
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --rendering-driver opengl3 \
##     --resolution 1280x720 res://world/vfx/tools/pager_outline_capture.tscn -- --out=<png>
## Owner: ENV C.
extends Node3D

var _out: String = "user://po6_20_outline.png"
var _frames: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	var root: Node3D = self
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.11, 0.13)
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	_box(root, Vector3(0, -0.05, 0), Vector3(30, 0.1, 40), Color(0.35, 0.34, 0.32))
	_box(root, Vector3(-1.5, 1.4, -2.0), Vector3(3.2, 2.8, 0.2), Color(0.75, 0.72, 0.66))  # the wall
	var po: PagerOutline = PagerOutline.new()
	root.add_child(po)
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0, 1.7, 5.0)
	root.add_child(cam)
	cam.look_at(Vector3(0, 1.0, -3.0))
	cam.current = true
	po.camera_override = cam
	var pid: int = 1
	for p: Vector3 in [Vector3(-1.5, 0, -4.0), Vector3(1.6, 0, -2.5), Vector3(5.0, 0, -18.0)]:
		var g: Node3D = _guard(root, p)
		var id: int = Ids.next()
		Ids.register(id, g)
		po._on_pager_started(pid, id)
		pid += 1


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 8:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("pager_outline_capture -> %s" % ProjectSettings.globalize_path(_out))
		get_tree().quit()


func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = c
	b.material = mat
	m.mesh = b
	m.position = pos
	parent.add_child(m)


func _guard(parent: Node3D, pos: Vector3) -> Node3D:
	var g: Node3D = Node3D.new()
	g.position = pos
	var vis: Node3D = Node3D.new()
	vis.name = "Visual"
	g.add_child(vis)
	var m: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.8
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.17, 0.22)
	cap.material = mat
	m.mesh = cap
	m.position = Vector3(0, 0.9, 0)
	vis.add_child(m)
	parent.add_child(g)
	return g
