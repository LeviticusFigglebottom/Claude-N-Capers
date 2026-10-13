## Viewmodel render probe on the small unit map (fast windowed): hip + ADS shots and the viewmodel meshes'
## layers / materials. Run under xvfb (not --headless): ... --path game res://tests/p/_review/vm_probe.tscn -- --out=DIR
## Owner: ENV P.
extends Node

var _out: String = "/tmp"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	var inp: PInputDriver = PInputDriver.new(self)
	var c: CrewController = rt.crew_controller(0) as CrewController
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	for _i: int in 90:
		await get_tree().physics_frame
	await _shot("vm_hip")
	_dump(c)
	inp.press(&"aim")
	for _i: int in 60:
		await get_tree().physics_frame
	await _shot("vm_ads")
	_dump(c)
	var vp: SubViewport = CrewView.of(c).find_child("Viewmodel", true, false) as SubViewport
	if vp != null:
		var img: Image = vp.get_texture().get_image()
		img.save_png("%s/vm_ads_subviewport.png" % _out)
		var mid: Color = img.get_pixel(img.get_width() / 2 + 60, img.get_height() * 3 / 4)
		print("[VM] subviewport size=%s format=%d px=%s corner=%s" % [vp.size, img.get_format(), mid,
			img.get_pixel(10, 10)])
	inp.release_all()
	get_tree().quit()


func _dump(c: CrewController) -> void:
	for n: Node in c.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = n as MeshInstance3D
		if (m.layers & CrewView.VIEWMODEL_LAYER) == 0 or not m.is_visible_in_tree():
			continue
		var mat: Material = m.get_active_material(0)
		var info: String = "none"
		if mat is StandardMaterial3D:
			var sm: StandardMaterial3D = mat as StandardMaterial3D
			info = "std albedo=%s shading=%d cull=%d tex=%s" % [sm.albedo_color, sm.shading_mode, sm.cull_mode,
				sm.albedo_texture != null]
		elif mat != null:
			info = mat.get_class()
		print("[VM] %s layers=%x surfaces=%d mat0=%s pos=%s" % [m.get_path(), m.layers,
			m.mesh.get_surface_count() if m.mesh != null else 0, info, m.global_position])


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[VM] shot ", name)
