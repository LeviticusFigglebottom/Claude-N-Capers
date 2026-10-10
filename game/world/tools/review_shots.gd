## Review screenshot renderer (level_standards §8). Owner: ENV C. Needs a GPU/xvfb (not headless):
## xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --path game --resolution 1920x1080 \
##   res://world/tools/review_shots.tscn -- --heist=<id> --stage=<g1|g2|g3> [--plan] [--out=<dir>]
##   [--scene=<res path>] [--cameras=a,b] [--warmup=<frames>]
## Renders every HeistMap.review_cameras node (Marker3D: meta fov, caption; TopDown*: orthographic,
## meta size) to <out>/<camera>.jpg (JPEG, <= 400 KB), contact_sheet.jpg and shots.md.
## --plan instead renders one top-down floor plan per floor (cut at floor + 1.5 m) with
## spawn/patrol/loot/zone overlays: <out>/plan_floor<i>.jpg (+ plan.md).
extends Node

const W: int = 1920
const H: int = 1080
const MAX_BYTES: int = 400000
const PLAN_CUT: float = 1.5
const PLAN_DEPTH: float = 2.5
const OVERLAY: Dictionary = {
	"player": Color(0.1, 0.9, 0.2), "guard": Color(0.95, 0.15, 0.1), "police": Color(0.2, 0.4, 1.0),
	"civilian": Color(1.0, 0.85, 0.1), "patrol": Color(1.0, 0.55, 0.0), "loot": Color(0.9, 0.2, 0.9),
	"use": Color(0.2, 0.9, 0.9), "escape": Color(0.2, 1.0, 0.4, 0.35), "secure": Color(0.9, 0.2, 0.9, 0.35),
}

var _cam: Camera3D
var _map: HeistMap
var _ctx: LcContext


func _ready() -> void:
	_main.call_deferred()


func _main() -> void:
	var args: Dictionary = preload("res://world/tools/validate_level.gd").parse_args(OS.get_cmdline_user_args())
	var heist: String = String(args.get("heist", ""))
	var stage: String = String(args.get("stage", "g1"))
	var scene_path: String = String(args.get("scene", ""))
	if scene_path == "":
		scene_path = "res://world/heists/%s/%s.tscn" % [heist, heist]
	var out_dir: String = String(args.get("out", ""))
	if out_dir == "":
		if heist == "":
			_quit(2, "usage: --heist=<id> or --scene=<path> --out=<dir>")
			return
		var root: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		out_dir = root.path_join("docs/levels/%s/%s" % [heist, stage])
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ps: PackedScene = load(scene_path) as PackedScene
	_map = ps.instantiate() as HeistMap if ps != null else null
	if _map == null:
		_quit(2, "cannot load a HeistMap from %s" % scene_path)
		return
	get_window().size = Vector2i(W, H)
	_ctx = await LcRunner.prepare(_map, self)
	_ensure_lighting(args.has("plan"))
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.far = 1000.0
	add_child(_cam)
	_cam.make_current()
	var warm: int = int(args.get("warmup", "12"))
	if args.has("plan"):
		await _render_plans(out_dir, warm, heist if heist != "" else String(_map.name))
	else:
		var filt: PackedStringArray = String(args.get("cameras", "")).split(",", false)
		await _render_shots(out_dir, warm, filt, heist if heist != "" else String(_map.name), stage)
	_quit(0, "review_shots: wrote %s" % out_dir)


func _quit(code: int, msg: String) -> void:
	print(msg)
	get_tree().quit(code)


## Greybox maps may have no lights yet: add neutral fill so shots are readable (never saved).
func _ensure_lighting(plan: bool) -> void:
	var has_light: bool = not _map.find_children("*", "Light3D", true, false).is_empty()
	var has_env: bool = not _map.find_children("*", "WorldEnvironment", true, false).is_empty()
	if not has_env:
		var we: WorldEnvironment = WorldEnvironment.new()
		var env: Environment = Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.12, 0.12, 0.14)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.6, 0.6, 0.62)
		env.ambient_light_energy = 0.8
		we.environment = env
		add_child(we)
	if not has_light or plan:
		var sun: DirectionalLight3D = DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-70.0, 30.0, 0.0)
		sun.light_energy = 0.6 if has_light else 1.0
		sun.shadow_enabled = false
		add_child(sun)


func _apply_camera(n: Node3D) -> void:
	_cam.global_transform = n.global_transform
	var cp: Dictionary = LcCheckPerf.camera_params(n)
	if float(cp["ortho"]) > 0.0:
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = float(cp["ortho"])
	else:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.fov = float(cp["fov"])
	_cam.near = 0.05
	_cam.far = 1000.0
	if n is Camera3D:
		_cam.near = (n as Camera3D).near
		_cam.far = (n as Camera3D).far


func _grab(warm: int) -> Image:
	for i: int in range(warm):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img.get_width() != W or img.get_height() != H:
		img.resize(W, H, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	return img


## Saves as JPEG at quality 85, lowering quality until the file is <= 400 KB.
static func save_jpg(img: Image, path: String) -> int:
	var q: float = 0.85
	var buf: PackedByteArray = img.save_jpg_to_buffer(q)
	while buf.size() > MAX_BYTES and q > 0.3:
		q -= 0.05
		buf = img.save_jpg_to_buffer(q)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return 0
	f.store_buffer(buf)
	f.close()
	return buf.size()


func _render_shots(out_dir: String, warm: int, filt: PackedStringArray, label: String, stage: String) -> void:
	var shots: Array[Dictionary] = []
	for np: NodePath in _map.review_cameras:
		var n: Node3D = _map.get_node_or_null(np) as Node3D
		if n == null or (not filt.is_empty() and not (String(n.name) in filt)):
			continue
		_apply_camera(n)
		var img: Image = await _grab(warm)
		var file: String = "%s.jpg" % String(n.name).to_snake_case()
		var size: int = save_jpg(img, out_dir.path_join(file))
		print("  %s -> %s (%d KB)" % [n.name, file, size / 1024])
		shots.append({"name": String(n.name), "file": file, "img": img,
			"caption": String(n.get_meta(&"caption", "")), "kb": size / 1024})
	if shots.is_empty():
		return
	var sheet: Image = await _contact_sheet(shots, warm)
	save_jpg(sheet, out_dir.path_join("contact_sheet.jpg"))
	var md: PackedStringArray = PackedStringArray()
	md.append("# Review shots: %s (%s)" % [label, stage])
	md.append("")
	md.append("Rendered by `tools/levelcheck/render_shots.sh` at %dx%d. Contact sheet: `contact_sheet.jpg`." % [W, H])
	md.append("")
	md.append("| # | camera | caption | file | KB |")
	md.append("|---|---|---|---|---|")
	for i: int in range(shots.size()):
		var s: Dictionary = shots[i]
		md.append("| %d | %s | %s | [%s](%s) | %d |" % [i + 1, s["name"], s["caption"], s["file"], s["file"], s["kb"]])
	md.append("")
	md.append("![contact sheet](contact_sheet.jpg)")
	md.append("")
	var f: FileAccess = FileAccess.open(out_dir.path_join("shots.md"), FileAccess.WRITE)
	f.store_string("\n".join(md))
	f.close()


## Grid of labelled thumbnails, rendered with Controls over the 3D view.
func _contact_sheet(shots: Array[Dictionary], warm: int) -> Image:
	var n: int = shots.size()
	var cols: int = 2
	for c: int in range(2, 11):
		cols = c
		var tw: float = float(W) / float(c)
		if ceili(float(n) / float(c)) * (tw * 9.0 / 16.0 + 26.0) <= float(H):
			break
	var tw2: int = W / cols
	var th: int = int(tw2 * 9.0 / 16.0)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.09)
	bg.size = Vector2(W, H)
	layer.add_child(bg)
	for i: int in range(n):
		var img: Image = (shots[i]["img"] as Image).duplicate() as Image
		img.resize(tw2 - 6, th - 6, Image.INTERPOLATE_BILINEAR)
		var tr: TextureRect = TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.position = Vector2((i % cols) * tw2 + 3, (i / cols) * (th + 26) + 3)
		layer.add_child(tr)
		var lb: Label = Label.new()
		lb.text = "%d  %s" % [i + 1, shots[i]["name"]]
		lb.position = tr.position + Vector2(2, th - 4)
		lb.add_theme_font_size_override(&"font_size", 16)
		layer.add_child(lb)
	var sheet: Image = await _grab(warm)
	layer.queue_free()
	return sheet


## Plan framing for floor `fi`: non-exterior RoomVolumes on that floor (any floor if none), else
## the Geometry bounds. Exterior site dressing is deliberately left out of the framing.
func _plan_box(fi: int) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for pass_i: int in range(2):
		for r: RoomVolume in _ctx.rooms:
			if r.purpose == &"exterior" or (pass_i == 0 and r.floor_index != fi):
				continue
			var a: AABB = LcAreas.world_aabb(r)
			box = a if first else box.merge(a)
			first = false
		if not first:
			return box
	var geo: Node = _map.get_node_or_null("Geometry")
	if geo != null:
		for n: Node in geo.find_children("*", "GeometryInstance3D", true, false):
			var gi: GeometryInstance3D = n
			var a2: AABB = gi.global_transform * gi.get_aabb()
			box = a2 if first else box.merge(a2)
			first = false
	return box


## Flat, neutral look for plans: overrides the map's environment/exposure through the camera.
func _apply_plan_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.adjustment_enabled = false
	_cam.environment = env
	_cam.attributes = CameraAttributesPractical.new()
	for n: Node in _map.find_children("*", "", true, false):
		if n is Decal or n is FogVolume or n is GPUParticles3D or n is CPUParticles3D:
			(n as Node3D).visible = false


func _render_plans(out_dir: String, warm: int, label: String) -> void:
	_apply_plan_environment()
	_apply_plan_materials()
	var overlay: Node3D = _build_overlay()
	var md: PackedStringArray = PackedStringArray(["# Floor plans: %s" % label, "",
		"Top-down orthographic, cut at floor + %.1f m. Overlay: player spawns green, guards red, police blue," % PLAN_CUT,
		"civilians yellow, patrol points/links orange, loot magenta, UsePoints cyan, escape zones green, secure zones magenta.", ""])
	var fh: PackedFloat32Array = _map.floor_heights
	for i: int in range(fh.size()):
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		var box: AABB = _plan_box(i)
		var margin: float = 1.5
		_cam.size = maxf(box.size.z, box.size.x * float(H) / float(W)) + margin * 2.0
		_cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0)),
			Vector3(box.get_center().x, fh[i] + PLAN_CUT, box.get_center().z))
		_cam.near = 0.01
		_cam.far = PLAN_DEPTH
		for c: Node in overlay.get_children():
			(c as Node3D).visible = absf(float(c.get_meta(&"floor_y", 0.0)) - fh[i]) < 1.2
		var img: Image = await _grab(warm)
		var file: String = "plan_floor%d.jpg" % i
		var size: int = save_jpg(img, out_dir.path_join(file))
		print("  floor %d (%.2f m) -> %s (%d KB)" % [i, fh[i], file, size / 1024])
		md.append("## Floor %d (%.2f m)" % [i, fh[i]])
		md.append("")
		md.append("![floor %d](%s)" % [i, file])
		md.append("")
	var f: FileAccess = FileAccess.open(out_dir.path_join("plan.md"), FileAccess.WRITE)
	f.store_string("\n".join(md))
	f.close()


## Plan look: everything double-sided and unshaded; faces seen from behind (= solids cut by the
## camera plane, e.g. walls) render black ("poché"), architecture light grey, props warm.
func _apply_plan_materials() -> void:
	var sh: Shader = Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 tint = vec3(0.8);
void fragment() {
	vec3 n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	ALBEDO = FRONT_FACING ? tint * (0.65 + 0.35 * abs(n.y)) : vec3(0.04);
	// Cut solids win over coplanar floors (reverse-Z: larger = closer).
	DEPTH = FRONT_FACING ? FRAGCOORD.z : min(FRAGCOORD.z + 0.02, 1.0);
}
"""
	var groups: Dictionary = {"Geometry": Color(0.86, 0.86, 0.84), "Props": Color(0.9, 0.68, 0.45),
		"Gameplay": Color(0.55, 0.78, 0.95), "Variants": Color(0.78, 0.62, 0.95), "": Color(0.7, 0.7, 0.7)}
	var mats: Dictionary = {}
	for gname: String in groups.keys():
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = sh
		var c: Color = groups[gname]
		m.set_shader_parameter(&"tint", Vector3(c.r, c.g, c.b))
		mats[gname] = m
	for n: Node in _map.find_children("*", "GeometryInstance3D", true, false):
		var top: Node = n
		while top.get_parent() != _map:
			top = top.get_parent()
		var key: String = String(top.name) if mats.has(String(top.name)) else ""
		(n as GeometryInstance3D).material_override = mats[key]


func _unshaded(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.no_depth_test = true
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _dot(parent: Node3D, pos: Vector3, key: String, r: float = 0.25) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.material = _unshaded(OVERLAY[key])
	mi.mesh = sm
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, pos.y + 0.4, pos.z)
	mi.set_meta(&"floor_y", _floor_of(pos.y))


func _floor_of(y: float) -> float:
	var best: float = 0.0
	for f: float in _map.floor_heights:
		if f <= y + 0.5:
			best = f
	return best


func _build_overlay() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "_PlanOverlay"
	add_child(root)
	for n: Node in _map.find_children("*", "", true, false):
		if n is SpawnPoint:
			var sp: SpawnPoint = n
			var key: String = {SpawnPoint.Kind.PLAYER: "player", SpawnPoint.Kind.GUARD: "guard",
				SpawnPoint.Kind.POLICE: "police", SpawnPoint.Kind.CIVILIAN: "civilian"}.get(sp.kind, "")
			if key != "":
				_dot(root, sp.global_position, key, 0.3)
		elif n is PatrolPoint:
			_dot(root, (n as Node3D).global_position, "patrol", 0.18)
		elif n.name == &"UsePoint" and n is Node3D:
			_dot(root, (n as Node3D).global_position, "use", 0.15)
		elif n is Node3D and LcTargets.is_loot_spawn(n):
			_dot(root, (n as Node3D).global_position, "loot", 0.25)
		elif n is MapZone and ((n as MapZone).kind == MapZone.Kind.ESCAPE or (n as MapZone).kind == MapZone.Kind.SECURE_LOOT):
			var z: MapZone = n
			var b: AABB = LcAreas.world_aabb(z)
			var mi: MeshInstance3D = MeshInstance3D.new()
			var pm: PlaneMesh = PlaneMesh.new()
			pm.size = Vector2(b.size.x, b.size.z)
			pm.material = _unshaded(OVERLAY["escape" if z.kind == MapZone.Kind.ESCAPE else "secure"])
			mi.mesh = pm
			root.add_child(mi)
			mi.global_position = Vector3(b.get_center().x, b.position.y + 0.3, b.get_center().z)
			mi.set_meta(&"floor_y", _floor_of(b.position.y))
	# Patrol links as thin lines, one mesh per floor (by the link's lower end).
	var meshes: Dictionary = {}
	for pn: Node in _map.find_children("*", "PatrolPoint", true, false):
		var p: PatrolPoint = pn
		for lp: NodePath in p.links:
			var t: Node3D = p.get_node_or_null(lp) as Node3D
			if t == null:
				continue
			var fy: float = _floor_of(minf(p.global_position.y, t.global_position.y))
			if not meshes.has(fy):
				var im: ImmediateMesh = ImmediateMesh.new()
				im.surface_begin(Mesh.PRIMITIVE_LINES, _unshaded(OVERLAY["patrol"]))
				meshes[fy] = im
			var imm: ImmediateMesh = meshes[fy]
			imm.surface_add_vertex(p.global_position + Vector3.UP * 0.4)
			imm.surface_add_vertex(t.global_position + Vector3.UP * 0.4)
	for fy2: float in meshes.keys():
		var im2: ImmediateMesh = meshes[fy2]
		im2.surface_end()
		var lines: MeshInstance3D = MeshInstance3D.new()
		lines.mesh = im2
		lines.set_meta(&"floor_y", fy2)
		root.add_child(lines)
	return root
