## Lead D-111 priority (PO: "untextured gun"): why the first-person WEAPON gets almost no light while the arms do.
## Windowed, on a lit heist (default Glasshouse, the crew's own spawn). Renders the viewmodel SubViewport with only
## the weapon, then only the arms (alpha = coverage), and prints the mean luminance of each under variants:
##   base        as shipped
##   metal0      weapon materials with metallic 0 (diagnostic: is it the metal / reflection path?)
##   omni        a debug OmniLight 0.4 m from the gun on the viewmodel layer
##   env_color   the viewmodel camera's environment with ambient / reflections from a colour, not the sky
##   world_lit   the viewmodel camera also sees layer-1 lights (the map's lights)
## Also dumps the weapon vs arms GeometryInstance settings, the weapon materials and the lights that reach the
## viewmodel. "[VML] ..." lines; frames in --out. Owner: ENV P.
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot [--rendering-driver opengl3] --path game \
##     --resolution 960x540 res://tests/p/_review/vm_light_probe.tscn -- --out=/abs/dir [--heist=glasshouse]
##     [--fills=0,1,1.5,2.5]  PO6-10 short run: only `fill_<e>` variants (the ViewmodelGunFill light at energy e;
##                            0 = off), then quit
extends Node

var _out: String = "user://vm_light_probe"
var _heist: StringName = &"glasshouse"
var _weapon: StringName = &"weapon.corsair_ar"
var _fills: PackedFloat64Array = []
var _c: CrewController = null
var _fp: FpViewmodel = null
var _vp: SubViewport = null
var _hidden: Array[GeometryInstance3D] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": _out = v
			"heist": _heist = StringName(v)
			"weapon": _weapon = StringName(v)
			"fills":
				for e: String in v.split(",", false):
					_fills.append(float(e))
	DirAccess.make_dir_recursive_absolute(_out)
	RenderingServer.render_loop_enabled = false
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.primary = _weapon
	l.primary_mods = [] as Array[StringName]
	l.resolved_primary = LoadoutResolver.resolve_weapon(_weapon, l.primary_mods)
	var rt: HeistRuntime = await HeistLauncher.launch(_heist, 1002, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "loadouts": {0: l}})
	rt.isolate_npc(null)
	_c = rt.crew_controller(0) as CrewController
	var inp: PInputDriver = PInputDriver.new(self)
	inp.capture_mouse()
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await inp.tap(&"slot_primary")
	for _i: int in 120:
		await get_tree().physics_frame
	var view: CrewView = CrewView.of(_c)
	_fp = view.fp_viewmodel()
	_vp = view.viewmodel_camera().get_viewport() as SubViewport if view.viewmodel_camera() != null else null
	print("[VML] renderer=%s driver=%s vp=%s" % [ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		RenderingServer.get_current_rendering_driver_name(), _vp != null])
	_dump(view)
	if not _fills.is_empty():
		var fill: DirectionalLight3D = view.find_child("ViewmodelGunFill", true, false) as DirectionalLight3D
		print("[VML] gun fill light: %s" % (fill != null))
		for e: float in _fills:
			if fill != null:
				fill.light_energy = e
				fill.visible = e > 0.0
			await _measure("fill_%s" % e)
		RenderingServer.render_loop_enabled = true
		print("[VML] RESULT DONE")
		get_tree().quit(0)
		return
	await _measure("base")
	var restore: Array[Callable] = []
	restore.append(_metal0())
	await _measure("metal0")
	restore.pop_back().call()
	restore.append(_metal0(true))
	await _measure("unshaded")
	restore.pop_back().call()
	restore.append(_metal0(true, "", true))
	await _measure("arms_unshaded")
	restore.pop_back().call()
	restore.append(_swap_to_arms_material())
	await _measure("arms_mat")
	restore.pop_back().call()
	restore.append(_metal0(false, "no_orm"))
	await _measure("no_orm")
	restore.pop_back().call()
	restore.append(_metal0(false, "no_orm_normal"))
	await _measure("no_orm_nrm")
	restore.pop_back().call()
	for tex: String in ["orm", "normal", "albedo"]:
		restore.append(_skin_with_gun_texture(tex))
		await _measure("skin+gun_" + tex)
		restore.pop_back().call()
	restore.append(_metal0(false, "no_normal"))
	await _measure("no_normal")
	restore.pop_back().call()
	var omni: OmniLight3D = OmniLight3D.new()
	omni.layers = CrewView.VIEWMODEL_LAYER
	omni.light_cull_mask = CrewView.VIEWMODEL_LAYER
	omni.omni_range = 2.0
	omni.light_energy = 1.0
	view.viewmodel_camera().add_child(omni)
	omni.position = Vector3(0.2, 0.15, -0.3)
	await _measure("omni")
	omni.queue_free()
	var env: Environment = view.viewmodel_camera().environment
	if env != null:
		var keep: Array = [env.ambient_light_source, env.reflected_light_source, env.ambient_light_color]
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.ambient_light_color = Color(0.55, 0.55, 0.6)
		await _measure("env_color")
		env.ambient_light_source = keep[0]
		env.reflected_light_source = keep[1]
		env.ambient_light_color = keep[2]
	if env != null:
		var k2: Array = [env.background_mode, env.background_color, env.ambient_light_source,
			env.reflected_light_source]
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.42, 0.42, 0.45, 0.0)  # alpha 0: the overlay stays transparent
		env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
		await _measure("env_bgcolor")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
		await _measure("env_bgcol_amb")
		env.background_mode = k2[0]
		env.background_color = k2[1]
		env.ambient_light_source = k2[2]
		env.reflected_light_source = k2[3]
	var vcam: Camera3D = view.viewmodel_camera()
	var mask: int = vcam.cull_mask
	vcam.cull_mask = mask | 1
	_hide_world_geometry(true)
	await _measure("world_lit")
	_hide_world_geometry(false)
	vcam.cull_mask = mask
	RenderingServer.render_loop_enabled = true
	print("[VML] RESULT DONE out=%s" % _out)
	get_tree().quit(0)


## Layer-1 world meshes would draw in the viewmodel image once the camera sees layer 1: hide them (lights stay).
func _hide_world_geometry(on: bool) -> void:
	if on:
		for n: Node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
			var g: GeometryInstance3D = n as GeometryInstance3D
			if g.layers & 1 and g.visible:
				g.visible = false
				_hidden.append(g)
	else:
		for g: GeometryInstance3D in _hidden:
			if is_instance_valid(g):
				g.visible = true
		_hidden.clear()


func _weapon_meshes() -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for n: Node in (_c.weapon_visual as Node3D).find_children("*", "GeometryInstance3D", true, false):
		out.append(n as GeometryInstance3D)
	return out


func _arms_meshes() -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	var gun: Node = _c.weapon_visual
	for n: Node in _fp.skeleton.find_children("*", "GeometryInstance3D", true, false):
		if gun == null or not (gun == n or gun.is_ancestor_of(n)):  # the gun hangs under the weapon bone
			out.append(n as GeometryInstance3D)
	return out


func _metal0(unshaded: bool = false, strip: String = "", arms: bool = false) -> Callable:
	var saved: Array[Array] = []
	for g: GeometryInstance3D in (_arms_meshes() if arms else _weapon_meshes()):
		var mi: MeshInstance3D = g as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var m: BaseMaterial3D = mi.get_active_material(s) as BaseMaterial3D
			if m == null:
				continue
			var d: BaseMaterial3D = m.duplicate() as BaseMaterial3D
			d.metallic = 0.0
			d.metallic_texture = null
			if unshaded:
				d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			if strip == "no_orm" and d is ORMMaterial3D:
				(d as ORMMaterial3D).orm_texture = null
				d.ao_enabled = false
				d.roughness = 0.6
			if strip == "no_normal" or strip == "no_orm_normal":
				d.normal_enabled = false
			if strip == "no_orm_normal" and d is ORMMaterial3D:
				(d as ORMMaterial3D).orm_texture = null
				d.ao_enabled = false
				d.roughness = 0.6
			saved.append([mi, s, mi.get_surface_override_material(s)])
			mi.set_surface_override_material(s, d)
	return func() -> void:
		for e: Array in saved:
			if is_instance_valid(e[0]):
				(e[0] as MeshInstance3D).set_surface_override_material(int(e[1]), e[2])


## Every weapon surface gets the skin material with ONE of the gun surface's own textures (orm / normal / albedo).
func _skin_with_gun_texture(which: String) -> Callable:
	var arms: MeshInstance3D = _fp.skeleton.get_node_or_null(^"Arms") as MeshInstance3D
	var skin: ORMMaterial3D = arms.get_active_material(0) as ORMMaterial3D if arms != null else null
	var saved: Array[Array] = []
	for g: GeometryInstance3D in _weapon_meshes():
		var mi: MeshInstance3D = g as MeshInstance3D
		if mi == null or mi.mesh == null or skin == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var own: ORMMaterial3D = mi.get_active_material(s) as ORMMaterial3D
			if own == null:
				continue
			var d: ORMMaterial3D = skin.duplicate() as ORMMaterial3D
			d.subsurf_scatter_enabled = false
			match which:
				"orm": d.orm_texture = own.orm_texture
				"normal": d.normal_texture = own.normal_texture
				"albedo": d.albedo_texture = own.albedo_texture
			saved.append([mi, s, mi.get_surface_override_material(s)])
			mi.set_surface_override_material(s, d)
	return func() -> void:
		for e: Array in saved:
			if is_instance_valid(e[0]):
				(e[0] as MeshInstance3D).set_surface_override_material(int(e[1]), e[2])


## Every weapon surface gets the Arms mesh's first material: material vs per-object lighting.
func _swap_to_arms_material() -> Callable:
	var arms: MeshInstance3D = _fp.skeleton.get_node_or_null(^"Arms") as MeshInstance3D
	var m: Material = arms.get_active_material(0) if arms != null else null
	var saved: Array[Array] = []
	for g: GeometryInstance3D in _weapon_meshes():
		var mi: MeshInstance3D = g as MeshInstance3D
		if mi == null or mi.mesh == null or m == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			saved.append([mi, s, mi.get_surface_override_material(s)])
			mi.set_surface_override_material(s, m)
	return func() -> void:
		for e: Array in saved:
			if is_instance_valid(e[0]):
				(e[0] as MeshInstance3D).set_surface_override_material(int(e[1]), e[2])


## Mean luminance (0..255) of the covered pixels with only `show` visible among weapon + arms.
func _lum(show_weapon: bool) -> Array:
	var w: Array[GeometryInstance3D] = _weapon_meshes()
	var a: Array[GeometryInstance3D] = _arms_meshes()
	var vis: Dictionary = {}
	for g: GeometryInstance3D in w + a:
		vis[g] = g.visible
	for g: GeometryInstance3D in w:
		g.visible = show_weapon and bool(vis[g])
	for g: GeometryInstance3D in a:
		g.visible = (not show_weapon) and bool(vis[g])
	RenderingServer.render_loop_enabled = true
	for _i: int in 3:
		await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	for g: GeometryInstance3D in vis:
		g.visible = bool(vis[g])
	var sum: float = 0.0
	var n: int = 0
	for y: int in range(0, img.get_height(), 2):
		for x: int in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.9:
				sum += (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) / c.a
				n += 1
	return [sum / maxf(n, 1) * 255.0, n, img]


func _measure(label: String) -> void:
	var w: Array = await _lum(true)
	var a: Array = await _lum(false)
	(w[2] as Image).save_png("%s/%s_weapon.png" % [_out, label])
	(a[2] as Image).save_png("%s/%s_arms.png" % [_out, label])
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_screen.png" % [_out, label])
	RenderingServer.render_loop_enabled = false
	print("[VML] %-10s weapon %.1f (%d px)  arms %.1f (%d px)" % [label, w[0], w[1], a[0], a[1]])


func _dump(view: CrewView) -> void:
	for pair: Array in [["weapon", _weapon_meshes()], ["arms", _arms_meshes()]]:
		for g: GeometryInstance3D in pair[1]:
			var b: Basis = g.global_basis
			print("[VML] %s %s layers=%d cast=%d gi=%d vis=%s det=%.3f scale=%s" % [pair[0], g.name, g.layers,
				g.cast_shadow, g.gi_mode, g.is_visible_in_tree(), b.determinant(), b.get_scale()])
	for g: GeometryInstance3D in _weapon_meshes():
		var mi: MeshInstance3D = g as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s: int in mini(mi.mesh.get_surface_count(), 3):
			var m: BaseMaterial3D = mi.get_active_material(s) as BaseMaterial3D
			if m != null:
				var tex: Texture2D = m.albedo_texture
				var avg: String = "-"
				if tex != null:
					var im: Image = tex.get_image()
					if im != null:
						if im.is_compressed():
							im.decompress()
						im.resize(8, 8, Image.INTERPOLATE_BILINEAR)
						var acc: Color = Color(0, 0, 0, 0)
						for yy: int in 8:
							for xx: int in 8:
								acc += im.get_pixel(xx, yy) / 64.0
						avg = "%s (%s)" % [acc, tex.resource_path.get_file()]
				print("[VML] mat %s/%d %s albedo=%s tex_avg=%s metallic=%.2f rough=%.2f normal=%s ao=%s cull=%d" % [
					mi.name, s, m.get_class(), m.albedo_color, avg, m.metallic, m.roughness,
					m.normal_texture.resource_path.get_file() if m.normal_enabled and m.normal_texture != null else "off",
					m.ao_enabled, m.cull_mode])
	var vcam: Camera3D = view.viewmodel_camera()
	var env: Environment = vcam.environment
	if env != null:
		print("[VML] vm env bg=%d ambient_src=%d energy=%.2f refl_src=%d sky=%s" % [env.background_mode,
			env.ambient_light_source, env.ambient_light_energy, env.reflected_light_source, env.sky != null])
	var reach: int = 0
	for n: Node in get_tree().root.find_children("*", "Light3D", true, false):
		var li: Light3D = n as Light3D
		if li.visible and li.layers & vcam.cull_mask and li.light_cull_mask & CrewView.VIEWMODEL_LAYER:
			reach += 1
	print("[VML] lights reaching the viewmodel: %d" % reach)
