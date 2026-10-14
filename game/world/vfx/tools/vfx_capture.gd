## Windowed impact capture sheet (D-086, impact_fx.md Tests: "a windowed capture sheet of every
## surface's impact"). Owner: ENV C. Lays out one tagged panel per surface, drives a VfxDirector purely
## through EventBus.shot_fx / explosion_fx (like ENV A will), and saves PNG frames + a sheet. Run:
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --rendering-driver opengl3 \
##     --fixed-fps 60 --resolution 1280x720 res://world/vfx/tools/vfx_capture.tscn -- --out=<dir> [--sheet=<png>]
## Options: --quality=<0..1> (VfxSettings.effects_quality), --cpu (CPUParticles3D), --bench (prints the
## average frame / render time with a sustained firefight vs idle; add --gpu-timing for render-time queries).
class_name VfxCaptureTool
extends Node3D

const COLS: int = 7
const CELL_W: float = 1.5
const PANEL: Vector3 = Vector3(1.2, 1.2, 0.2)
const ROW_H: float = 1.55
const CAM_POS: Vector3 = Vector3(0.0, 1.5, 5.2)
## Surface -> world material library id ("" = a flat colour from FLAT).
const MATERIALS: Dictionary[StringName, String] = {
	&"concrete": "concrete", &"brick": "brick_red", &"plaster": "plaster_painted", &"tile": "tile_ceramic_white",
	&"wood": "wood_veneer_walnut", &"metal": "steel_bare", &"glass": "glass_clear", &"fabric": "fabric_upholstery",
	&"armor": "alu_anodized_black", &"shield": "metal_matte",
}
const FLAT: Dictionary[StringName, Color] = {
	&"dirt": Color(0.3, 0.23, 0.16), &"water": Color(0.12, 0.2, 0.26), &"flesh": Color(0.55, 0.42, 0.36),
}
## Weapon class used against each panel (cycles).
const CLASSES: Array[StringName] = [&"assault_rifle", &"pistol", &"smg", &"shotgun", &"lmg", &"sniper"]
## Frames: warm-up, then volleys every VOLLEY_EVERY frames; captures at these frame numbers.
const VOLLEY_START: int = 20
const VOLLEY_EVERY: int = 9
const VOLLEYS: int = 8
const CAPTURES: Array[int] = [22, 25, 30, 40, 92]
const SHEET_FRAMES: Array[int] = [25, 30, 92]

var _out_dir: String = "user://vfx_capture"
var _sheet_path: String = ""
var _bench: bool = false
## Viewport render-time queries (they stall llvmpipe badly: ~2.4 s/frame; off by default).
var _gpu_timing: bool = false
var _frame: int = 0
var _volley: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _director: VfxDirector
var _targets: Array[Dictionary] = []
var _shots: Dictionary[int, Image] = {}
var _bench_acc: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
## Per phase: draw calls, objects, primitives (summed).
var _bench_draw: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _bench_last_us: int = 0


func _ready() -> void:
	_rng.seed = 0xCAB7
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
		elif arg.begins_with("--sheet="):
			_sheet_path = arg.substr(8)
		elif arg.begins_with("--quality="):
			VfxSettings.effects_quality = arg.substr(10).to_float()
		elif arg == "--cpu":
			VfxSettings.force_cpu_particles = true
		elif arg == "--bench":
			_bench = true
		elif arg == "--gpu-timing":
			_gpu_timing = true
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_build_stage()
	_director = (load("res://world/vfx/vfx_director.tscn") as PackedScene).instantiate() as VfxDirector
	add_child(_director)
	if _gpu_timing:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	print("vfx_capture: renderer=%s decals=%s cpu_particles=%s" % [RenderingServer.get_current_rendering_method(),
		"nodes" if _director.decals.use_decal_nodes else "quads", VfxSettings.use_cpu_particles()])


func _process(_delta: float) -> void:
	_frame += 1
	if _bench:
		_bench_step()
		return
	if _frame >= VOLLEY_START and (_frame - VOLLEY_START) % VOLLEY_EVERY == 0 and _volley < VOLLEYS:
		_fire_volley()
		_volley += 1
	if _frame == VOLLEY_START + 2:
		EventBus.explosion_fx.emit(Vector3(3.2, 0.0, 1.6), 2.5, &"frag")
	if _frame in CAPTURES:
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		_shots[_frame] = img
		print("vfx_capture: frame %d stats %s" % [_frame, _director.stats()])
		img.save_png(_out_dir.path_join("vfx_frame_%03d.png" % _frame))
		if _frame == CAPTURES[CAPTURES.size() - 1]:
			_finish()


func _finish() -> void:
	if _sheet_path != "":
		_save_sheet()
	print("vfx_capture: frames -> %s, stats %s" % [ProjectSettings.globalize_path(_out_dir), _director.stats()])
	get_tree().quit(0)


## Sheet: SHEET_FRAMES stacked as halves (640x360 each) under the final full frame's top region.
func _save_sheet() -> void:
	var full: Image = _shots[SHEET_FRAMES[SHEET_FRAMES.size() - 1]].duplicate() as Image
	full.convert(Image.FORMAT_RGB8)
	var w: int = full.get_width()
	var h: int = full.get_height()
	var small_w: int = w / 2
	var small_h: int = h / 2
	var sheet: Image = Image.create(w, h + small_h, false, Image.FORMAT_RGB8)
	sheet.blit_rect(full, Rect2i(0, 0, w, h), Vector2i(0, 0))
	for i: int in range(2):
		var src: Image = (_shots[SHEET_FRAMES[i]].duplicate() as Image)
		src.convert(Image.FORMAT_RGB8)
		src.resize(small_w, small_h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(src, Rect2i(0, 0, small_w, small_h), Vector2i(i * small_w, h))
	sheet.save_png(_sheet_path)
	print("vfx_capture: sheet -> %s" % _sheet_path)


func _fire_volley() -> void:
	for t: Dictionary in _targets:
		var surf: StringName = t["surface"]
		var c: Vector3 = t["center"]
		var cls: StringName = CLASSES[(_volley + int(t["index"])) % CLASSES.size()]
		var origin: Vector3 = t["muzzle"]
		var pellets: int = 6 if cls == &"shotgun" else 1
		for p: int in range(pellets):
			var hit: Vector3 = c + Vector3(_rng.randf_range(-0.42, 0.42), _rng.randf_range(-0.42, 0.42), PANEL.z * 0.5)
			var flags: int = 0
			if surf == &"flesh" and _volley % 3 == 2:
				flags |= VfxDirector.FLAG_HEADSHOT
			EventBus.shot_fx.emit(origin, hit, Vector3.BACK, ImpactFx.surface_of(t["body"]), cls,
				1000 + int(t["index"]), flags)
	# A long lateral burst so tracers are visible crossing the frame.
	var y: float = _rng.randf_range(0.9, 2.4)
	EventBus.shot_fx.emit(Vector3(-28.0, y, 2.6), Vector3(12.0, y + 0.3, 2.2), Vector3.ZERO, &"", &"sniper", 77, 0)


func _build_stage() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.055, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.56)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.6
	we.environment = env
	add_child(we)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.light_energy = 1.1
	key.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	add_child(key)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var fb: BoxShape3D = BoxShape3D.new()
	fb.size = Vector3(30, 0.2, 14)
	floor_shape.shape = fb
	floor_body.add_child(floor_shape)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var fm: BoxMesh = BoxMesh.new()
	fm.size = fb.size
	floor_mesh.mesh = fm
	floor_mesh.material_override = _material_for(&"concrete")
	floor_body.add_child(floor_mesh)
	floor_body.position = Vector3(0, -0.1, 3.0)
	add_child(floor_body)
	for i: int in range(ImpactFx.SURFACES.size()):
		_add_panel(i, ImpactFx.SURFACES[i])
	var cam: Camera3D = Camera3D.new()
	cam.position = CAM_POS
	cam.fov = 62.0
	add_child(cam)
	cam.look_at(Vector3(0.0, 1.45, 0.0))
	cam.current = true


func _add_panel(i: int, surface: StringName) -> void:
	var row: int = i / COLS
	var col: int = i % COLS
	var count: int = COLS if row == 0 else ImpactFx.SURFACES.size() - COLS
	var x: float = (float(col) - float(count - 1) * 0.5) * CELL_W
	var center: Vector3 = Vector3(x, 0.75 + ROW_H * float(1 - row), 0.0)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Panel_%s" % surface
	# Tag like a kit piece would; flesh is a character (group), not a tag.
	if surface == &"flesh":
		body.add_to_group(G.NPC)
	else:
		body.set_meta(&"surface", surface)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = PANEL
	cs.shape = shape
	body.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = PANEL
	mi.mesh = bm
	mi.material_override = _material_for(surface)
	body.add_child(mi)
	body.position = center
	add_child(body)
	var label: Label3D = Label3D.new()
	label.text = String(surface)
	label.font_size = 40
	label.pixel_size = 0.004
	label.outline_size = 8
	label.position = center + Vector3(0, -PANEL.y * 0.5 - 0.09, 0.15)
	add_child(label)
	var muzzle: Vector3 = Vector3(x - 0.5, center.y - 0.45, 1.3)
	_targets.append({"surface": surface, "center": center, "body": body, "muzzle": muzzle, "index": i})


func _material_for(surface: StringName) -> Material:
	var id: String = MATERIALS.get(surface, "")
	if id != "" and ResourceLoader.exists("res://world/materials/%s.tres" % id):
		return load("res://world/materials/%s.tres" % id) as Material
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = FLAT.get(surface, Color(0.5, 0.5, 0.5))
	m.roughness = 0.15 if surface == &"water" else 0.8
	if surface == &"water":
		m.metallic_specular = 1.0
	return m


## Bench: frames 1-120 idle, 121-300 a sustained firefight (4 rays/frame = 240 rays/s across surfaces,
## an explosion every 120 frames). Prints mean CPU/GPU render ms (frames 61-120 vs 181-300: pools warm)
## and mean wall-clock frame ms per phase.
func _bench_step() -> void:
	var rid: RID = get_viewport().get_viewport_rid()
	var now: int = Time.get_ticks_usec()
	var wall: float = float(now - _bench_last_us) / 1000.0 if _bench_last_us > 0 else 0.0
	_bench_last_us = now
	var phase: int = -1
	if _frame > 60 and _frame <= 120:
		phase = 0
	elif _frame > 180 and _frame <= 300:
		phase = 1
	if phase >= 0:
		_bench_acc[phase * 3] += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		_bench_acc[phase * 3 + 1] += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		_bench_acc[phase * 3 + 2] += wall
		_bench_draw[phase * 3] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_bench_draw[phase * 3 + 1] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		_bench_draw[phase * 3 + 2] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	if _frame > 120:
		for k: int in range(4):
			var t: Dictionary = _targets[_rng.randi_range(0, _targets.size() - 1)]
			var c: Vector3 = t["center"]
			var hit: Vector3 = c + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5), PANEL.z * 0.5)
			EventBus.shot_fx.emit(t["muzzle"], hit, Vector3.BACK, t["surface"], &"assault_rifle", 2000 + k, 0)
		if _frame % 120 == 0:
			EventBus.explosion_fx.emit(Vector3(_rng.randf_range(-4, 4), 0, 2.5), 3.0, &"frag")
	if _frame % 60 == 0:
		print("vfx_bench: frame %d" % _frame)
	if _frame == 300:
		print("vfx_bench: idle cpu %.3f gpu %.3f wall %.2f ms | firefight cpu %.3f gpu %.3f wall %.2f ms | %s" % [
			_bench_acc[0] / 60.0, _bench_acc[1] / 60.0, _bench_acc[2] / 60.0,
			_bench_acc[3] / 120.0, _bench_acc[4] / 120.0, _bench_acc[5] / 120.0, _director.stats()])
		print("vfx_bench: draw calls / objects / primitives  idle %.0f / %.0f / %.0f  firefight %.0f / %.0f / %.0f" % [
			_bench_draw[0] / 60.0, _bench_draw[1] / 60.0, _bench_draw[2] / 60.0,
			_bench_draw[3] / 120.0, _bench_draw[4] / 120.0, _bench_draw[5] / 120.0])
		get_tree().quit(0)
