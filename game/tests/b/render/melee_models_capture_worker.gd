## Worker for melee_models_capture.gd (loaded at runtime so autoloads exist when it compiles).
## Frames: 01 side view from +X (edge / striking face to the right), 02 three-quarter view.
extends Node3D

const PER_ROW: int = 6
const STEP_X: float = 0.30
const ROW_H: float = 0.95

var _out: String = ""
var _cam: Camera3D


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/melee_models"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.33, 0.34, 0.36)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.58)
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 60.0, 0.0)
	sun.light_energy = 1.6
	add_child(sun)
	var holder: Node3D = Node3D.new()
	add_child(holder)
	var i: int = 0
	for r: Variant in ContentDB.all_melees():
		var d: MeleeDef = r as MeleeDef
		var slot: Node3D = Node3D.new()
		# Laid out in the camera plane: +Z of the slot row runs to screen right for the side view.
		slot.position = Vector3(0.0, -ROW_H * (i / PER_ROW), -STEP_X * (i % PER_ROW))
		holder.add_child(slot)
		if d.model != null:
			slot.add_child(d.model.instantiate())
		var mark: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.03, 0.004, 0.004)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.1, 0.1)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.material = mat
		mark.mesh = bm
		mark.rotation_degrees = Vector3(0, 90, 0)
		slot.add_child(mark)
		i += 1
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 2.1
	add_child(_cam)
	var centre: Vector3 = Vector3(0.0, 0.25 - ROW_H * 0.5, -STEP_X * (PER_ROW - 1) * 0.5)
	_cam.look_at_from_position(centre + Vector3(3.0, 0.0, 0.0), centre, Vector3.UP)
	await _shot("01_side")
	_cam.look_at_from_position(centre + Vector3(2.4, 0.9, 1.5), centre, Vector3.UP)
	await _shot("02_three_quarter")
	get_tree().quit()


func _shot(tag: String) -> void:
	for _i: int in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("MELEE MODELS SHOT ", path)
