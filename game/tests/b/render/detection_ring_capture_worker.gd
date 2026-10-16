## Worker for detection_ring_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const HUD_SCENE: String = "res://content/ui/hud/hud.tscn"

var _out: String = ""
var _model: MockHudModel
var _guards: Array[Vector3] = [Vector3(0.4, -1.6, -9.0), Vector3(-3.2, -1.6, -7.0), Vector3(7.5, -1.6, -1.5)]


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/detection_ring"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	OnboardingTips.persist = false
	_world()
	_model = MockHudModel.new()
	add_child(_model)
	var hud: Hud = (load(HUD_SCENE) as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	add_child(hud)
	await get_tree().process_frame
	hud.bind(_model)
	var drv: MockHudDriver = MockHudDriver.new()
	drv.model = _model
	drv.setup_initial()
	drv.free()
	_model.casing = false
	_model.masked = true
	_model.player_mode = &"masked"
	_model.heist_phase = Enums.HeistPhase.STEALTH
	_model.interaction = {}
	await _shot("01_filling_30", [_d(1, 0, 0.3)])
	await _shot("02_filling_70", [_d(1, 0, 0.7)])
	await _shot("03_detected", [_d(1, 0, 1.0)])
	await _shot("04_two_observers", [_d(1, 0, 0.45), _d(2, 1, 0.8)])
	await _shot("05_side_and_investigating", [_d(3, 2, 0.6), _d(2, 1, 0.0, &"investigating")])
	await _shot("06_camera", [{"observer_net_id": 9, "world_pos": Vector3(-1.2, 1.4, -6.0), "value": 0.55,
			"kind": Enums.ObserverKind.CAMERA}])
	get_tree().quit()


func _d(id: int, guard: int, value: float, state: StringName = &"") -> Dictionary:
	var d: Dictionary = {"observer_net_id": id, "world_pos": _guards[guard], "value": value,
			"kind": Enums.ObserverKind.GUARD}
	if state != &"":
		d["state"] = state
	return d


func _world() -> void:
	var w: Node3D = Node3D.new()
	add_child(w)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.36, 0.38, 0.40)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	w.add_child(env)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	w.add_child(light)
	var cam: Camera3D = Camera3D.new()
	w.add_child(cam)
	cam.current = true
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(40, 40)
	floor_mesh.position = Vector3(0, -1.6, -8)
	w.add_child(floor_mesh)
	for g: Vector3 in _guards:
		var body: MeshInstance3D = MeshInstance3D.new()
		body.mesh = CapsuleMesh.new()
		(body.mesh as CapsuleMesh).height = 1.8
		(body.mesh as CapsuleMesh).radius = 0.3
		body.position = g + Vector3(0, 0.9, 0)
		w.add_child(body)
	var camera_box: MeshInstance3D = MeshInstance3D.new()
	camera_box.mesh = BoxMesh.new()
	(camera_box.mesh as BoxMesh).size = Vector3(0.3, 0.2, 0.4)
	camera_box.position = Vector3(-1.2, 1.4, -6.0)
	w.add_child(camera_box)


func _shot(tag: String, rows: Array) -> void:
	var typed: Array[Dictionary] = []
	for r: Variant in rows:
		typed.append(r as Dictionary)
	_model.detection = typed
	for _i: int in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("RING SHOT ", path)
