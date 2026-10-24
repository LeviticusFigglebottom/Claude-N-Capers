## D-165 crowd LOD2 colour pop under club light (windowed): every look with a CrowdLod (default: the 42 club_* looks)
## is shot alone at the LOD2 switch distance, idle pose, once on its full meshes (LOD0/1) and once forced onto its
## CrowdLod proxy, on the Velvet's floor light (render_ah_dance_review's neon stage) and a transparent background.
## Over the character's own pixels (alpha) it measures the linear mean colour of both and prints, worst first:
##   [POP] <id> dL=<LOD2 - LOD0 luminance, % of LOD0> dC=<RGB distance of the linear means> L0=<lum> L2=<lum>
## With --strip it also writes lod2_pop_<tag>.png: per look, LOD0 | LOD2 at the switch distance (4x nearest).
## --calibrate: writes CrowdLod.GAIN_PATH: per look off by more than CAL_MIN, its gain times L0/L2 (clamped 1..GAIN_MAX,
## never darker), the rest keep theirs; then re-assemble (tools/blender/characters/assemble.sh) and re-measure.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --rendering-driver opengl3 --path game \
##     --script res://world/characters/_tools/render_lod2_pop.gd -- [--ids=a,b] [--dist=15] [--strip --tag=x --out=/abs]
## Owner: ENV D.
extends SceneTree

const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
## render several times the 1080p pixel density so the means are not a handful of pixels
const SUPER: int = 4
## --calibrate: only looks whose LOD2 luminance is off by more than this share get a gain; gains stay within 1..GAIN_MAX
const CAL_MIN: float = 0.05
const GAIN_MAX: float = 1.6

var _ids: PackedStringArray = []
var _dist: float = CrowdLod.CROWD_SWITCH_M
var _strip: bool = false
var _tag: String = "club"
var _out: String = ""
var _calibrate: bool = false
var _vp: SubViewport
var _cam: Camera3D


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		match kv[0]:
			"ids":
				_ids = kv[1].split(",")
			"dist":
				_dist = float(kv[1])
			"strip":
				_strip = true
			"tag":
				_tag = kv[1]
			"out":
				_out = kv[1]
			"calibrate":
				_calibrate = true
	if _ids.is_empty():
		for d: String in DirAccess.get_directories_at("res://world/characters"):
			if d.begins_with("club_") and ResourceLoader.exists("res://world/characters/%s/%s.tscn" % [d, d]):
				_ids.append(d)
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_lod2_pop: run under xvfb-run")
		quit(2)
		return
	var h_px: int = int(ceil(2.1 / (2.0 * _dist * tan(deg_to_rad(30.0))) * 1080.0)) * SUPER
	var size: Vector2i = Vector2i(int(h_px * 0.6), h_px)
	_stage(size)
	var rows: Array = []
	var tiles: Array[Image] = []
	for id: String in _ids:
		var body: Node3D = (load("res://world/characters/%s/%s.tscn" % [id, id]) as PackedScene).instantiate() as Node3D
		_vp.add_child(body)
		var ap: AnimationPlayer = body.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap != null and ap.has_animation("humanoid/idle"):
			ap.play("humanoid/idle")
			ap.seek(0.0, true)
			ap.pause()
		var shots: Array[Image] = []
		var means: Array = []
		for lod2: bool in [false, true]:
			if not CrowdLod.force_level(body, lod2):
				push_error("render_lod2_pop: %s has no CrowdLod" % id)
				break
			var img: Image = await _grab()
			shots.append(img)
			means.append(_mean(img))
		if means.size() == 2:
			var m0: Vector3 = means[0]
			var m2: Vector3 = means[1]
			var l0: float = _lum(m0)
			var l2: float = _lum(m2)
			rows.append([id, (l2 - l0) / maxf(l0, 1e-4) * 100.0, m0.distance_to(m2), l0, l2])
			if _strip:
				tiles.append(shots[0])
				tiles.append(shots[1])
		body.queue_free()
		await process_frame
	rows.sort_custom(func(a: Array, b: Array) -> bool: return absf(float(a[1])) > absf(float(b[1])))
	for r: Array in rows:
		print("[POP] %-22s dL=%+6.1f%% dC=%.4f L0=%.4f L2=%.4f" % r)
	if _strip and not tiles.is_empty():
		_save_strip(tiles, size)
	if _calibrate:
		_write_gains(rows)
	quit(0)


func _write_gains(rows: Array) -> void:
	var gains: Dictionary = {}
	for id: String in _ids:
		var g: float = CrowdLod.gain_for(id)
		if not is_equal_approx(g, 1.0):
			gains[id] = g
	for r: Array in rows:
		var l0: float = r[3]
		var l2: float = r[4]
		if absf(l2 - l0) / maxf(l0, 1e-4) <= CAL_MIN or l2 <= 0.0:
			continue
		var g: float = clampf(CrowdLod.gain_for(String(r[0])) * l0 / l2, 1.0, GAIN_MAX)
		gains[String(r[0])] = snappedf(g, 0.01)
	var keys: Array = gains.keys()
	keys.sort()
	var ordered: Dictionary = {}
	for k: String in keys:
		ordered[k] = gains[k]
	var doc: Dictionary = {"doc": "D-165 ENV D: per-look LOD2 (CrowdLod) brightness gain, linear, measured under the Velvet's "
		+ "floor light at %.0f m by render_lod2_pop.gd --calibrate; read by crowd_lod.gd gain_for (assembler)." % _dist,
		"gain": ordered}
	var f: FileAccess = FileAccess.open(CrowdLod.GAIN_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  ", false) + "\n")
	f.close()
	print("render_lod2_pop: wrote %s (%d looks)" % [CrowdLod.GAIN_PATH, ordered.size()])


## Linear mean RGB over pixels with alpha >= 0.5 (the viewport renders sRGB; decoded here).
func _mean(img: Image) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var l: Color = c.srgb_to_linear()
			sum += Vector3(l.r, l.g, l.b)
			n += 1
	return sum / float(maxi(n, 1))


func _lum(c: Vector3) -> float:
	return 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z


func _save_strip(tiles: Array[Image], size: Vector2i) -> void:
	var w: int = size.x / SUPER
	var h: int = size.y / SUPER
	var strip: Image = Image.create(w * tiles.size() * 4, h * 4, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.05, 0.04, 0.07))
	for i: int in tiles.size():
		var t: Image = tiles[i].duplicate() as Image
		t.resize(w, h, Image.INTERPOLATE_BILINEAR)          # back to 1080p pixel density
		t.resize(w * 4, h * 4, Image.INTERPOLATE_NEAREST)
		strip.blend_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i(i * w * 4, 0))
	DirAccess.make_dir_recursive_absolute(_out)
	strip.save_png("%s/lod2_pop_%s.png" % [_out, _tag])
	print("render_lod2_pop: wrote %s/lod2_pop_%s.png" % [_out, _tag])


## The Velvet's floor light (render_ah_dance_review._stage): dark room, magenta key, violet fill; transparent background.
## The camera stands at -Z looking at the character's front (characters face -Z).
func _stage(size: Vector2i) -> void:
	_vp = SubViewport.new()
	_vp.size = size
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.35, 0.25, 0.55)
	env.environment.ambient_light_energy = 0.35
	_vp.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, 160.0, 0.0)
	key.light_color = Color(1.0, 0.35, 0.75)
	key.light_energy = 1.3
	_vp.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -30.0, 0.0)
	fill.light_color = Color(0.45, 0.38, 1.0)
	fill.light_energy = 0.8
	_vp.add_child(fill)
	_cam = Camera3D.new()
	# the 1080p / 60 degree pixel density of a character at --dist (SUPER x the pixels, same framing)
	_cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(30.0)) * float(size.y / SUPER) / 1080.0))
	_cam.far = 100.0
	_vp.add_child(_cam)
	_cam.current = true
	_cam.look_at_from_position(Vector3(0.0, 1.65, -_dist), Vector3(0.0, 0.95, 0.0), Vector3.UP)


func _grab() -> Image:
	for _i: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
