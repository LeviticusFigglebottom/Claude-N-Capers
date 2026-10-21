## Rolling Thunder cast lineups for the PO (LEAD 2026-10-21, after D-149): one lit 1920x1080 contact sheet per group,
## every look shown front and three-quarter front (idle, full LOD), captioned, under a title band. Owner: ENV D.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy \
##     --rendering-driver opengl3 --path game --script res://world/characters/_tools/render_rt_lineup.gd \
##     [-- --group=convoy]
##
## Groups (GROUPS; all by default): convoy (marshal and Vaultline crew), escorts (by difficulty, rolling_thunder.md
## "Convoy units per difficulty": the D-145.3 duty look on Routine/Tense, then the TAC set and its faction reskins),
## street_reused (the twelve OF day looks the street pool reuses), street_rt (the nine RT pedestrians and the diner /
## booth staff), site (Halden site guards and the beat cop), specials (Reyes). Writes
## res://assets/characters/_review/rt_lineup/rt_lineup_<group>.png.
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const OUT_DIR: String = "res://assets/characters/_review/rt_lineup/"
const SHEET: Vector2i = Vector2i(1920, 1080)
const TITLE_H: int = 64
## a view's width / height (one figure, head to feet, with a caption line)
const VIEW_ASPECT: float = 0.36
## group -> [title, [[caption prefix, character id], ...]]
const GROUPS: Dictionary = {
	"convoy": ["Rolling Thunder - convoy: route marshal (vl_marshal) and Vaultline crew a-f (convoy_t1-3)", [
		["marshal", "armored_car_marshal"], ["", "armored_car_crew"], ["", "armored_car_crew_b"],
		["", "armored_car_crew_c"], ["", "armored_car_crew_d"], ["", "armored_car_crew_e"], ["", "armored_car_crew_f"],
	]],
	"escorts": ["Rolling Thunder - convoy escorts by difficulty (lead / rear car; director EnemyDefs, D-145.3, D-149.12)", [
		["Routine/Tense", "patrol_officer_duty"],
		["Hazardous", "tac_light"], ["Hazardous", "tac_heavy"],
		["Brutal", "tac_light_frd"], ["Brutal", "tac_heavy_frd"],
		["Lethal", "tac_light_sentinel"], ["Lethal", "tac_heavy_sentinel"], ["Lethal rare", "wrecker_sentinel"],
		["Cataclysm", "tac_light_zero"], ["Cataclysm", "tac_heavy_zero"], ["Cataclysm", "wrecker_zero"],
	]],
	"street_reused": ["Rolling Thunder - street / bus / diner civilians, reused Ostrander day looks (12 of 21)", [
		["", "bank_customer"], ["", "bank_customer_b"], ["", "bank_customer_c"], ["", "bank_customer_d"],
		["", "bank_customer_e"], ["", "bank_customer_f"], ["", "bank_customer_g"], ["", "bank_customer_h"],
		["", "bank_customer_i"], ["", "bank_customer_j"], ["", "civilian_customer_a"], ["", "civilian_customer_b"],
	]],
	"street_rt": ["Rolling Thunder - RT street pedestrians a-i (g-i: finish swaps of a/b/f) and the diner / booth staff", [
		["", "street_pedestrian"], ["", "street_pedestrian_b"], ["", "street_pedestrian_c"],
		["", "street_pedestrian_d"], ["", "street_pedestrian_e"], ["", "street_pedestrian_f"],
		["swap of a", "street_pedestrian_g"], ["swap of b", "street_pedestrian_h"], ["swap of f", "street_pedestrian_i"],
		["staff_diner", "diner_waitress"], ["staff_diner", "diner_cook"], ["staff_booth", "carpark_attendant"],
	]],
	"site": ["Rolling Thunder - Tanner's Reach site guards (Halden, guard_site_*) and the beat cop (cop_plaza / cop_diner)", [
		["", "security_officer"], ["", "security_officer_b"], ["", "security_officer_c"], ["", "security_officer_d"],
		["", "security_officer_e"], ["", "security_officer_f"], ["", "security_officer_g"], ["", "security_officer_h"],
		["", "security_officer_i"], ["", "security_officer_j"], ["beat cop", "patrol_officer"],
	]],
	"specials": ["Rolling Thunder - specials: Hollis \"Hammer\" Reyes, the fixer in the ram mixer's cab (driver_mixer)", [
		["Reyes", "contact_hollis"],
	]],
}

var _vp: SubViewport
var _cam: Camera3D
var _label: Label3D
var _errors: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_rt_lineup: --headless has no renderer; run under xvfb-run")
		quit(2)
		return
	var groups: Array = GROUPS.keys()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--group="):
			groups = [arg.trim_prefix("--group=")]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_stage()
	for g: Variant in groups:
		if not GROUPS.has(g):
			_errors += 1
			push_error("render_rt_lineup: unknown group %s (%s)" % [g, GROUPS.keys()])
			continue
		await _sheet(String(g))
	quit(1 if _errors > 0 else 0)


## The grid with the largest views that fits n figures (two views each) under the title band.
func _grid(n: int) -> Vector3i:
	var best: Vector3i = Vector3i(n, 1, 0)
	var best_h: int = 0
	for cols: int in range(1, n + 1):
		var rows: int = ceili(float(n) / cols)
		var h: int = (SHEET.y - TITLE_H) / rows
		var w: int = SHEET.x / (cols * 2)
		h = mini(h, int(w / VIEW_ASPECT))
		if h > best_h:
			best_h = h
			best = Vector3i(cols, rows, h)
	return best


func _sheet(group: String) -> void:
	var title: String = String(GROUPS[group][0])
	var looks: Array = GROUPS[group][1]
	var g: Vector3i = _grid(looks.size())
	var view: Vector2i = Vector2i(mini(SHEET.x / (g.x * 2), int(g.z * VIEW_ASPECT * 1.4)), g.z)
	var sheet: Image = Image.create(SHEET.x, SHEET.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.16, 0.16, 0.17))
	sheet.blit_rect(await _title(title), Rect2i(0, 0, SHEET.x, TITLE_H), Vector2i.ZERO)
	var used_w: int = view.x * 2 * g.x
	var x_off: int = (SHEET.x - used_w) / 2
	var y_off: int = TITLE_H + (SHEET.y - TITLE_H - view.y * g.y) / 2
	for i: int in range(looks.size()):
		var prefix: String = String(looks[i][0])
		var id: String = String(looks[i][1])
		var x: int = x_off + view.x * 2 * (i % g.x)
		var y: int = y_off + view.y * (i / g.x)
		var path: String = Spec.scene_path("char_" + id)
		if not ResourceLoader.exists(path):
			_errors += 1
			push_error("render_rt_lineup: no scene for %s" % id)
			continue
		var body: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		CrowdLod.force_level(body, false)
		_vp.add_child(body)
		var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
		if player.has_animation("humanoid/idle"):
			player.play("humanoid/idle")
			player.seek(0.0, true)
			player.pause()
		_vp.size = view
		_label.pixel_size = 0.0022 * clampf(500.0 / view.y, 1.0, 1.6)
		_label.text = id if prefix.is_empty() else "%s\n%s" % [prefix, id]
		_label.visible = true
		var front: Image = await _grab(Vector3(0.0, 1.05, -4.6), Vector3(0.0, 1.0, 0.0))
		sheet.blit_rect(front, Rect2i(Vector2i.ZERO, view), Vector2i(x, y))
		_label.visible = false
		var three_q: Image = await _grab(Vector3(-3.2, 1.1, -3.3), Vector3(0.0, 1.0, 0.0))
		sheet.blit_rect(three_q, Rect2i(Vector2i.ZERO, view), Vector2i(x + view.x, y))
		body.queue_free()
		await process_frame
	var file: String = "%srt_lineup_%s.png" % [OUT_DIR, group]
	if sheet.save_png(file) != OK:
		_errors += 1
		push_error("render_rt_lineup: could not save %s" % file)
	else:
		print("render_rt_lineup: wrote %s (%d looks, %dx%d grid, view %dx%d)" % [file, looks.size(), g.x, g.y,
			view.x, view.y])


## The title band as an image (a 2D SubViewport with one Label).
func _title(text: String) -> Image:
	var tv: SubViewport = SubViewport.new()
	tv.size = Vector2i(SHEET.x, TITLE_H)
	tv.transparent_bg = false
	tv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(tv)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.11)
	bg.size = Vector2(SHEET.x, TITLE_H)
	tv.add_child(bg)
	var lab: Label = Label.new()
	lab.text = text
	lab.position = Vector2(24.0, 12.0)
	lab.add_theme_font_size_override("font_size", 30)
	lab.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	tv.add_child(lab)
	for _i: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = tv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	tv.queue_free()
	return img


func _stage() -> void:
	_vp = SubViewport.new()
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
	env.environment.ambient_light_energy = 0.45
	_vp.add_child(env)
	# RT is the first daylight heist: a warm low key from the front-left, a cool fill, a rim from behind
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32.0, 205.0, 0.0)
	key.light_energy = 0.85
	key.light_color = Color(1.0, 0.95, 0.86)
	key.shadow_enabled = true
	_vp.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 140.0, 0.0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.85, 0.9, 1.0)
	_vp.add_child(fill)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25.0, 10.0, 0.0)
	rim.light_energy = 0.3
	_vp.add_child(rim)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	floor_mesh.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.31)
	floor_mesh.material_override = mat
	_vp.add_child(floor_mesh)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, 2.12, 0.0)
	_label.pixel_size = 0.0022
	_label.font_size = 40
	_label.outline_size = 8
	_vp.add_child(_label)
	_cam = Camera3D.new()
	_cam.fov = 34.0
	_cam.far = 100.0
	_vp.add_child(_cam)
	_cam.current = true


func _grab(eye: Vector3, target: Vector3) -> Image:
	_cam.global_transform = Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP).translated(eye)
	for _i: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
