## Worker for npc_weapon_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/npc_weapons"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var root: Node3D = Node3D.new()
	add_child(root)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.36, 0.37, 0.4)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	root.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	root.add_child(sun)
	var ids: Array[StringName] = []
	for npc_id: StringName in NpcWeaponModels.data().models:
		var def: WeaponDef = NpcWeaponModels.weapon_def(npc_id)
		if def != null and not ids.has(def.id):
			ids.append(def.id)
	for i: int in ids.size():
		var def: WeaponDef = ContentDB.weapon(ids[i])
		var y: float = 0.9 - (i % 4) * 0.55
		var x: float = -2.6 if i < 4 else 0.25
		var full: WeaponVisual = WeaponVisual.new()
		root.add_child(full)
		full.setup(def, [] as Array[WeaponModDef])
		full.position = Vector3(x, y, 0)
		full.rotation_degrees = Vector3(0, -90, 0)
		var merged: WeaponVisual = WeaponVisual.new()
		root.add_child(merged)
		merged.setup_npc(def)
		merged.position = Vector3(x + 1.2, y, 0)
		merged.rotation_degrees = Vector3(0, -90, 0)
	var cam: Camera3D = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.6
	cam.position = Vector3(0.0, 0.1, 3.0)
	await _shot("close")
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 75.0
	cam.position = Vector3(0.0, 0.1, 3.5)
	await _shot("far")
	get_tree().quit(0)


func _shot(tag: String) -> void:
	for _i: int in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/npc_weapons_%s_%dx%d.png" % [_out, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("NPCW SHOT ", path)
