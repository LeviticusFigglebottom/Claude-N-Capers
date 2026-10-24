## Review screenshot renderer (level_standards §8). Owner: ENV C. Needs a GPU/xvfb (not headless):
## xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --path game --resolution 1920x1080 \
##   res://world/tools/review_shots.tscn -- --heist=<id> --stage=<g1|g2|g3> [--plan] [--out=<dir>]
##   [--scene=<res path>] [--cameras=a,b] [--warmup=<frames>] [--probe-warmup=<frames per probe>]
## Renders every HeistMap.review_cameras node (Marker3D: meta fov, caption; TopDown*: orthographic,
## meta size) to <out>/<camera>.jpg (JPEG, <= 400 KB), contact_sheet.jpg and shots.md.
## --plan instead renders one top-down floor plan per floor (cut at floor + 1.5 m) with
## spawn/patrol/loot/zone overlays: <out>/plan_floor<i>.jpg (+ plan.md).
## --blueprint renders the clean pre-planning blueprint (preplanning.md, D-038): no debug markers,
## walls/doors/windows/stairs/major furniture + room labels, floors side by side:
## docs/levels/<id>/blueprint.png (+ blueprint_floor<i>.png) and
## game/world/heists/<id>/<id>_blueprint.png (PNG, <= 1 MB). With --scene, --out=<dir> only.
extends Node

const W: int = 1920
const H: int = 1080
const MAX_BYTES: int = 400000
const PLAN_CUT: float = 1.5
const PLAN_DEPTH: float = 2.5
const BP_MAX_BYTES: int = 1000000
const PROBE_WARM_FRAMES: int = 24
## A --cameras run warms only the UPDATE_ONCE probes whose box (grown by this) holds a chosen camera.
const PROBE_NEAR_M: float = 8.0
## The main view's 3D render scale while the probes warm (their cube maps keep their own resolution).
const WARM_SCALE: float = 0.1
const BP_GROUND: Color = Color(0.09, 0.22, 0.42)
const BP_FLOOR: Color = Color(0.13, 0.29, 0.52)
const BP_LINE: Color = Color(0.93, 0.96, 1.0)
const BP_FURN: Color = Color(0.36, 0.55, 0.78)
const BP_DOOR: Color = Color(0.72, 0.86, 1.0)
## Props smaller than this footprint (m²) are clutter, not furniture: hidden on the blueprint.
const BP_MIN_FOOTPRINT: float = 0.2
## Wall cut: collision sampled on this grid (m) at floor + BP_CUT_SAMPLE_Y (kit wall meshes are open
## at top/bottom, so the rendered cut cannot be trusted; colliders can).
const BP_CELL: float = 0.04
const BP_CUT_SAMPLE_Y: float = 1.2
const OVERLAY: Dictionary = {
	"player": Color(0.1, 0.9, 0.2), "guard": Color(0.95, 0.15, 0.1), "police": Color(0.2, 0.4, 1.0),
	"civilian": Color(1.0, 0.85, 0.1), "patrol": Color(1.0, 0.55, 0.0), "loot": Color(0.9, 0.2, 0.9),
	"use": Color(0.2, 0.9, 0.9), "escape": Color(0.2, 1.0, 0.4, 0.35), "secure": Color(0.9, 0.2, 0.9, 0.35),
}

var _cam: Camera3D
var _map: HeistMap
var _ctx: LcContext
var _bp_shell: ShaderMaterial = null


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
	var blueprint: bool = args.has("blueprint")
	var root_dir: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	if blueprint and out_dir == "" and heist != "":
		out_dir = root_dir.path_join("docs/levels/%s" % heist)
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
	_ensure_lighting(args.has("plan") or blueprint)
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.far = 1000.0
	add_child(_cam)
	_cam.make_current()
	var warm: int = int(args.get("warmup", "12"))
	await _warm_probes(int(args.get("probe-warmup", str(PROBE_WARM_FRAMES))),
		String(args.get("cameras", "")).split(",", false))
	if blueprint:
		var label: String = heist if heist != "" else String(_map.name)
		var extra: String = ""
		if heist != "" and not args.has("scene"):
			extra = root_dir.path_join("game/world/heists/%s/%s_blueprint.png" % [heist, heist])
		await _render_blueprint(out_dir, extra, warm, label)
	elif args.has("plan"):
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


## UPDATE_ONCE ReflectionProbes render only once a camera sees them, over ~14-20 frames. Library metals
## (ORM metallic) have no diffuse, so until their probe has rendered they read black whenever the
## environment's reflected light source is disabled. Visit every such probe from its own centre first so
## the first shot never catches it unrendered (black-faces root cause, LEAD approval (a)). With --cameras only the
## probes holding (within PROBE_NEAR_M of) a chosen camera are warmed: a large map's every probe x frames is hours on
## lavapipe.
func _warm_probes(frames: int, filt: PackedStringArray = PackedStringArray()) -> void:
	if frames <= 0:
		return
	var eyes: Array[Vector3] = []
	for np: NodePath in _map.review_cameras:
		var c: Node3D = _map.get_node_or_null(np) as Node3D
		if c != null and String(c.name) in filt:
			eyes.append(c.global_position)
	var probes: Array[ReflectionProbe] = []
	for n: Node in _map.find_children("*", "ReflectionProbe", true, false):
		var rp: ReflectionProbe = n as ReflectionProbe
		if rp.visible and rp.update_mode == ReflectionProbe.UPDATE_ONCE and _probe_near(rp, eyes):
			probes.append(rp)
	# the probes render their own cube faces: the main view can draw at a tenth of the resolution meanwhile (lavapipe:
	# a 1080p frame is ~10 s, so a large map's warm-up took hours)
	var vp: Viewport = get_viewport()
	var scale_was: float = vp.scaling_3d_scale
	vp.scaling_3d_scale = WARM_SCALE
	for rp: ReflectionProbe in probes:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.global_transform = Transform3D(Basis.IDENTITY, rp.global_position)
		for i: int in range(frames):
			await get_tree().process_frame
	vp.scaling_3d_scale = scale_was
	if not probes.is_empty():
		print("  warmed %d reflection probe(s), %d frames each" % [probes.size(), frames])


## A review camera's meta `club_lights` (Afterhours: "club" | "house"): Lighting/ClubLights is set to that state for
## the shot (default "club", so a house shot never leaks into the next one).
## A review camera's meta `stage_convoy` (a convoy layout id, e.g. "north_clean"): that layout is applied
## (ConvoyLayouts) and every mover of its route parked on its `<Veh>Stop`, so the shot shows the convoy at the stop
## (LEAD r305 G3: the convoy shots showed an empty road). Review only: the map's own state is the start state.
func _stage_convoy(id: String) -> void:
	var layout: Node3D = ConvoyLayouts.find(_map, id)
	if layout == null:
		push_warning("review_shots: no convoy layout %s" % id)
		return
	ConvoyLayouts.apply(_map, id, ConvoyLayouts.group_of(layout))
	var movers: Node = layout.get_parent().get_node_or_null("Movers")
	if movers != null:
		for v: Node in movers.get_children():
			var stop: Node3D = layout.get_node_or_null(NodePath(String(v.name) + "Stop")) as Node3D
			if v is Node3D and stop != null:
				(v as Node3D).global_transform = Transform3D(stop.global_basis.orthonormalized(), stop.global_position)
				(v as Node3D).visible = true
	await get_tree().process_frame


## True when `eyes` is empty (every probe) or one eye is inside the probe's box grown by PROBE_NEAR_M.
static func _probe_near(rp: ReflectionProbe, eyes: Array[Vector3]) -> bool:
	if eyes.is_empty():
		return true
	var box: AABB = AABB(rp.global_position - rp.size * 0.5, rp.size).grow(PROBE_NEAR_M)
	for e: Vector3 in eyes:
		if box.has_point(e):
			return true
	return false


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
		if n.has_meta(&"stage_convoy"):
			await _stage_convoy(String(n.get_meta(&"stage_convoy")))
		var lights: Node = _map.get_node_or_null("Lighting/ClubLights")
		if lights != null and lights.has_method(&"set_state"):
			lights.call(&"set_state", StringName(String(n.get_meta(&"club_lights", "club"))))
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
		print("  floor %d %s (%s) -> %s (%d KB)" % [i, display_floor_name(_map, i), fmt_height(fh[i]), file, size / 1024])
		var fname: String = _map.floor_name(i)
		md.append("## %s (%s)" % [fname if fname != "" else floor_name(fh, i).capitalize(), fmt_height(fh[i])])
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


# --- blueprint (pre-planning board) -----------------------------------------------------------

func _render_blueprint(out_dir: String, extra_path: String, warm: int, label: String) -> void:
	_apply_plan_environment()
	_cam.environment.background_color = BP_GROUND
	_apply_blueprint_materials()
	var fh: PackedFloat32Array = _map.floor_heights
	# One framing for every floor so the side-by-side composite shares a scale.
	var box: AABB = _plan_box(0)
	for fi: int in range(1, fh.size()):
		box = box.merge(_plan_box(fi))
	var margin: float = 2.0
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = maxf(box.size.z + margin * 2.0, (box.size.x + margin * 2.0) * float(H) / float(W))
	var floors: Array[Image] = []
	for i: int in range(fh.size()):
		_cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0)),
			Vector3(box.get_center().x, fh[i] + PLAN_CUT, box.get_center().z))
		_cam.near = 0.01
		_cam.far = PLAN_DEPTH
		await get_tree().process_frame
		var layer: CanvasLayer = _blueprint_labels(i, label)
		var img: Image = await _grab(warm)
		layer.queue_free()
		floors.append(img)
		var fsize: int = save_png_limited(img, out_dir.path_join("blueprint_floor%d.png" % i))
		print("  blueprint floor %d %s -> blueprint_floor%d.png (%d KB)" % [i, display_floor_name(_map, i), i, fsize / 1024])
	var comp: Image = _compose(floors)
	var size: int = save_png_limited(comp, out_dir.path_join("blueprint.png"))
	print("  blueprint -> %s (%dx%d, %d KB)" % [out_dir.path_join("blueprint.png"), comp.get_width(), comp.get_height(), size / 1024])
	if extra_path != "":
		DirAccess.make_dir_recursive_absolute(extra_path.get_base_dir())
		save_png_limited(comp, extra_path)
		print("  blueprint -> %s" % extra_path)


## Floor name by height, not index: 0.0 -> GROUND FLOOR, below ground -> BASEMENT B1, B2...
## (B1 nearest the ground), above -> FLOOR 1, 2... counted from the ground floor.
static func floor_name(fh: PackedFloat32Array, i: int) -> String:
	var ground: int = -1
	for k: int in range(fh.size()):
		if absf(fh[k]) < 0.001:
			ground = k
	if ground < 0:
		return "LEVEL %d" % i
	if i == ground:
		return "GROUND FLOOR"
	if i < ground:
		return "BASEMENT B%d" % (ground - i)
	return "FLOOR %d" % (i - ground)


## Display name of floor i (D-054): the map's HeistMap.floor_name(i) when non-empty, else the
## height-based name above.
static func display_floor_name(map: HeistMap, i: int) -> String:
	var n: String = map.floor_name(i)
	return n if n != "" else floor_name(map.floor_heights, i)


## Signed height with a real minus sign: "+4.2 m", "−4.0 m", "0.0 m".
static func fmt_height(y: float) -> String:
	if absf(y) < 0.05:
		return "0.0 m"
	return "%s%.1f m" % ["+" if y > 0.0 else "−", absf(y)]


## Floors side by side (2 per row), separated by a thin gap in the ground colour.
static func _compose(floors: Array[Image]) -> Image:
	if floors.size() == 1:
		return floors[0]
	var cols: int = mini(2, floors.size())
	var rows: int = ceili(float(floors.size()) / float(cols))
	var gap: int = 24
	var out: Image = Image.create_empty(W * cols + gap * (cols - 1), H * rows + gap * (rows - 1), false, Image.FORMAT_RGB8)
	out.fill(BP_GROUND.darkened(0.3))
	for i: int in range(floors.size()):
		out.blit_rect(floors[i], Rect2i(0, 0, W, H), Vector2i((i % cols) * (W + gap), (i / cols) * (H + gap)))
	return out


## PNG, downscaled in 10% steps until the file is <= BP_MAX_BYTES.
static func save_png_limited(img: Image, path: String) -> int:
	var work: Image = img
	var buf: PackedByteArray = work.save_png_to_buffer()
	while buf.size() > BP_MAX_BYTES and work.get_width() > 640:
		work = img.duplicate() as Image
		var f: float = sqrt(float(BP_MAX_BYTES) / float(buf.size())) * 0.95
		work.resize(maxi(640, int(work.get_width() * f)), maxi(360, int(work.get_height() * f)), Image.INTERPOLATE_LANCZOS)
		buf = work.save_png_to_buffer()
	var fa: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if fa == null:
		return 0
	fa.store_buffer(buf)
	fa.close()
	return buf.size()


## Blueprint look: unshaded; cut solids (seen from behind) are drawn in the line colour for the
## shell and doors, in the furniture colour for props; surfaces below the cut are floor tone,
## lightened with height so stair treads read as bands. Variant content, clutter, lighting
## fixtures and site dressing outside the framing are hidden.
func _apply_blueprint_materials() -> void:
	var sh: Shader = Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 face_color : source_color = vec3(0.13, 0.29, 0.52);
uniform vec3 cut_color : source_color = vec3(0.93, 0.96, 1.0);
uniform vec3 high_color : source_color = vec3(0.93, 0.96, 1.0);
uniform float floor_y = 0.0;
uniform float height_tint = 0.0;
void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp((wp.y - floor_y) / 1.5, 0.0, 1.0);
	ALBEDO = FRONT_FACING ? mix(face_color, high_color, h * height_tint) : cut_color;
	DEPTH = FRONT_FACING ? FRAGCOORD.z : min(FRAGCOORD.z + 0.02, 1.0);
}
"""
	# Cut shell solids render dark: walls come from the collision poché (_cut_overlay), so what is
	# left cut in the render is neighbouring site masses, which should read as "outside".
	var shell: ShaderMaterial = _bp_mat(sh, BP_FLOOR, BP_GROUND.darkened(0.25), 0.55)
	var furn: ShaderMaterial = _bp_mat(sh, BP_FURN, BP_FURN.lightened(0.25), 0.0)
	var door: ShaderMaterial = _bp_mat(sh, BP_DOOR, BP_DOOR, 0.0)
	var small: Dictionary = {}
	for p: LcProp in _ctx.props:
		var fp: float = p.global_aabb.size.x * p.global_aabb.size.z
		if fp < BP_MIN_FOOTPRINT and not p.is_door and not p.is_window and p.kind != &"stairs":
			small[p.node] = true
	for n: Node in _map.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n
		var top: Node = gi
		while top.get_parent() != _map:
			top = top.get_parent()
		var p2: LcProp = _ctx.prop_of(gi)
		if top.name == &"Variants" or top.name == &"Lighting" or (p2 != null and small.has(p2.node)):
			gi.visible = false
			continue
		if p2 != null and (p2.is_door or p2.is_window):
			gi.material_override = door
		elif top.name == &"Geometry" or (p2 != null and p2.kind == &"stairs"):
			gi.material_override = shell
		elif top.name == &"Gameplay" and p2 == null:
			gi.material_override = door
		else:
			gi.material_override = furn
	_bp_shell = shell



static func _bp_mat(sh: Shader, face: Color, cut: Color, height_tint: float) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"face_color", Vector3(face.r, face.g, face.b))
	m.set_shader_parameter(&"cut_color", Vector3(cut.r, cut.g, cut.b))
	m.set_shader_parameter(&"high_color", Vector3(BP_LINE.r, BP_LINE.g, BP_LINE.b))
	m.set_shader_parameter(&"height_tint", height_tint)
	return m


static func _room_title(r: RoomVolume) -> String:
	var t: String = String(r.purpose).replace("_", " ").to_upper()
	return "%s\n%s" % [t, r.room_id] if r.room_id != &"" else t


## Room labels (projected room centres), title, north arrow and a 5 m scale bar.
func _blueprint_labels(fi: int, label: String) -> CanvasLayer:
	if _bp_shell != null:
		_bp_shell.set_shader_parameter(&"floor_y", _map.floor_heights[fi])
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var px_per_m: float = float(H) / _cam.size
	layer.add_child(_cut_overlay(fi, px_per_m))
	for r: RoomVolume in _ctx.rooms:
		if r.floor_index != fi or r.purpose == &"exterior":
			continue
		var b: AABB = LcAreas.world_aabb(r)
		var c: Vector3 = Vector3(b.get_center().x, _map.floor_heights[fi], b.get_center().z)
		var sp: Vector2 = _cam.unproject_position(c)
		var lb: Label = Label.new()
		lb.text = _room_title(r)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var fs: int = clampi(int(minf(b.size.x, b.size.z) * px_per_m / 9.0), 11, 26)
		lb.add_theme_font_size_override(&"font_size", fs)
		lb.add_theme_color_override(&"font_color", BP_LINE)
		lb.add_theme_color_override(&"font_outline_color", BP_GROUND)
		lb.add_theme_constant_override(&"outline_size", 6)
		layer.add_child(lb)
		lb.reset_size()
		lb.position = sp - lb.size * 0.5
	var title: Label = Label.new()
	title.text = "%s  -  %s  (%s)" % [label.to_upper(), display_floor_name(_map, fi).to_upper(),
		fmt_height(_map.floor_heights[fi])]
	title.position = Vector2(28, 18)
	title.add_theme_font_size_override(&"font_size", 34)
	title.add_theme_color_override(&"font_color", BP_LINE)
	var plate: ColorRect = ColorRect.new()
	plate.color = Color(BP_GROUND.r, BP_GROUND.g, BP_GROUND.b, 0.85)
	layer.add_child(plate)
	layer.add_child(title)
	title.reset_size()
	plate.position = title.position - Vector2(14, 8)
	plate.size = title.size + Vector2(28, 16)
	var bar: ColorRect = ColorRect.new()
	bar.color = BP_LINE
	bar.size = Vector2(5.0 * px_per_m, 6)
	bar.position = Vector2(32, H - 44)
	layer.add_child(bar)
	var bl: Label = Label.new()
	bl.text = "5 m"
	bl.position = Vector2(40 + 5.0 * px_per_m, H - 58)
	bl.add_theme_font_size_override(&"font_size", 22)
	bl.add_theme_color_override(&"font_color", BP_LINE)
	layer.add_child(bl)
	var north: Label = Label.new()
	north.text = "N\n^"
	north.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	north.position = Vector2(W - 70, 20)
	north.add_theme_font_size_override(&"font_size", 28)
	north.add_theme_color_override(&"font_color", BP_LINE)
	layer.add_child(north)
	return layer


## Poché of the wall cut from collision: point queries on a BP_CELL grid at floor + 1.2 m inside
## the floor's rooms (+0.8 m), shell in the line colour, cut furniture in a light furniture tone.
## Solids with a walkable top within 1 m above the sample (landings, stair ramps) are left to the
## render so stair treads stay readable.
func _cut_overlay(fi: int, px_per_m: float) -> TextureRect:
	var y: float = _map.floor_heights[fi] + BP_CUT_SAMPLE_Y
	var rooms: Array[AABB] = []
	for r: RoomVolume in _ctx.rooms:
		if r.floor_index == fi and r.purpose != &"exterior":
			rooms.append(LcAreas.world_aabb(r).grow(0.8))
	var box: AABB = _plan_box(fi).grow(0.8)
	var gw: int = ceili(box.size.x / BP_CELL)
	var gh: int = ceili(box.size.z / BP_CELL)
	var img: Image = Image.create_empty(gw, gh, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var q: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	q.collision_mask = LcContext.QUERY_MASK
	var space: PhysicsDirectSpaceState3D = _ctx.space()
	var furn: Color = BP_FURN.lightened(0.35)
	for j: int in range(gh):
		var z: float = box.position.z + (float(j) + 0.5) * BP_CELL
		for i: int in range(gw):
			var x: float = box.position.x + (float(i) + 0.5) * BP_CELL
			var pt: Vector3 = Vector3(x, y, z)
			var inside: bool = false
			for rb: AABB in rooms:
				if x >= rb.position.x and x <= rb.end.x and z >= rb.position.z and z <= rb.end.z:
					inside = true
					break
			if not inside:
				continue
			q.position = pt
			var hits: Array[Dictionary] = space.intersect_point(q, 4)
			for h: Dictionary in hits:
				var col: Node = h.get("collider") as Node
				if col == null or not _ctx.is_active(col) or LcUtil.slot_of(col) != null:
					continue
				var p: LcProp = _ctx.prop_of(col)
				if p == null or p.kind == &"stairs":
					# Landings / stair ramps / counters top out just above the cut: the render shows
					# them; only wall-like solids (no walkable top within 1 m) become poché.
					var top: Dictionary = _ctx.ray(pt + Vector3.UP * 1.0, pt, func(hh: Dictionary) -> bool:
						return (hh["normal"] as Vector3).y > 0.7)
					if top.is_empty():
						img.set_pixel(i, j, BP_LINE)
					break
				if not (p.is_door or p.is_window):
					img.set_pixel(i, j, furn)
	var tr: TextureRect = TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var c: Vector3 = _cam.global_position
	tr.position = Vector2(float(W) * 0.5 + (box.position.x - c.x) * px_per_m, float(H) * 0.5 + (box.position.z - c.z) * px_per_m)
	tr.size = Vector2(gw * BP_CELL * px_per_m, gh * BP_CELL * px_per_m)
	return tr
