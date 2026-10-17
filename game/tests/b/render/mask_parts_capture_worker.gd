## Worker for mask_parts_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const PATTERNS: Array[StringName] = [&"mask_pattern.guilloche", &"mask_pattern.vault_bolts", &"mask_pattern.acanthus",
	&"mask_pattern.facets", &"mask_pattern.time_lock_dial", &"mask_pattern.stencil"]
const MATERIALS: Array[StringName] = [&"mask_material.limestone", &"mask_material.bronze", &"mask_material.oil_canvas",
	&"mask_material.container_rust", &"mask_material.velvet_case", &"mask_material.night_safe",
	&"mask_material.gilt_leaf"]

var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/mask_parts"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var root: Node3D = Node3D.new()
	add_child(root)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	root.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 25, 0)
	root.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.95
	cam.position = Vector3(0.0, 0.0, 2.0)
	root.add_child(cam)
	cam.current = true
	for i: int in range(PATTERNS.size()):
		_place(root, &"mask_material.matte", PATTERNS[i], Vector3(-0.6 + i * 0.24, 0.3, 0.0), false)
		_place(root, &"mask_material.matte", PATTERNS[i], Vector3(-0.6 + i * 0.24, 0.02, 0.0), true)
	for i: int in range(MATERIALS.size()):
		_place(root, MATERIALS[i], &"mask_pattern.guilloche", Vector3(-0.72 + i * 0.24, -0.28, 0.0), true)
	for _i: int in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/mask_parts_%dx%d.png" % [_out, img.get_width(), img.get_height()]
	img.save_png(path)
	print("MASKS SHOT ", path)
	get_tree().quit(0)


func _place(root: Node3D, material: StringName, pattern: StringName, pos: Vector3, use_tex: bool) -> void:
	var comp: Dictionary = {MaskCatalog.BASE: "mask_base.visage", MaskCatalog.MATERIAL: String(material),
		MaskCatalog.COLORS: "mask_colors.bone_ink", MaskCatalog.PATTERN: String(pattern)}
	var def: MaskDef = MaskComposer.compose(comp)
	if def == null:
		print("MASKS compose failed ", material, " ", pattern)
		return
	var n: Node3D = MaskComposer.instantiate(def)
	n.position = pos
	n.rotation_degrees = Vector3(0, 180, 0)
	n.scale = Vector3.ONE * 0.9
	root.add_child(n)
	if not use_tex:
		for c: Node in n.find_children("*", "MeshInstance3D", true, false):
			var sm: ShaderMaterial = (c as MeshInstance3D).material_override as ShaderMaterial
			if sm != null:
				sm.set_shader_parameter(&"use_pattern_tex", false)
