## D-130 casts (Cataclysm: about +50 % guards and +35 % civilians on Gallery Night, Shadow Ledger and Night Deposit;
## GN-D1 standard, no twins): windowed review of one pool per run. Owner: ENV D.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy \
##     --rendering-driver opengl3 --path game --script res://world/characters/_tools/render_d130_cast_review.gd \
##     -- --pool=gn_guards
##
## Pools: gn_guards, sl_guards, nd_guards, civilians. Writes to res://assets/characters/_review/d130_cast/:
##   <pool>_sheet.png           per character: full body front (idle), three-quarter back mid-walk, head close-up
##   <pool>_lineup_30m.png      all of them side by side seen from 30 m (natural LOD switching, telephoto framing)
##   <pool>_silhouette_30m.png  the same view with every surface flat black (the 30 m silhouette read)
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const OUT_DIR: String = "res://assets/characters/_review/d130_cast/"
const POOLS: Dictionary = {
	"gn_guards": [
		"char_gallery_guard", "char_gallery_guard_b", "char_gallery_guard_c", "char_gallery_guard_d",
		"char_gallery_guard_e", "char_gallery_guard_f", "char_gallery_guard_g", "char_gallery_guard_h",
		"char_gallery_guard_i",
	],
	"sl_guards": [
		"char_npc_northgate_guard", "char_npc_northgate_guard_b", "char_npc_northgate_guard_c",
		"char_npc_northgate_guard_d", "char_npc_northgate_guard_e", "char_npc_northgate_guard_f",
		"char_npc_northgate_guard_g", "char_npc_northgate_guard_h", "char_npc_northgate_guard_i",
	],
	"nd_guards": [
		"char_security_officer", "char_security_officer_b", "char_security_officer_c", "char_security_officer_d",
		"char_security_officer_e", "char_security_officer_f",
	],
	"civilians": [
		"char_npc_cleaner_sl", "char_npc_cleaner_sl_b", "char_npc_cleaner_sl_c", "char_npc_cleaner_sl_d",
		"char_npc_bank_cleaner", "char_npc_bank_cleaner_b", "char_gallery_patron", "char_gallery_patron_b",
		"char_gallery_patron_c", "char_gallery_patron_d", "char_gallery_patron_e", "char_gallery_patron_f",
		"char_gallery_patron_g", "char_gallery_patron_h", "char_gallery_patron_i", "char_gallery_patron_j",
		"char_npc_penthouse_guest_a", "char_npc_penthouse_guest_b",
	],
}
const COLS: int = 9
const TILE: Vector2i = Vector2i(200, 340)
const HEAD_TILE: Vector2i = Vector2i(200, 200)
const WALK_T: float = 0.3
const LINEUP_SIZE: Vector2i = Vector2i(2400, 420)
const LINEUP_SPACING: float = 1.3
const LINEUP_DIST: float = 30.0

var _pool: String = "gn_guards"
var _chars: Array[String] = []
var _vp: SubViewport
var _cam: Camera3D
var _label: Label3D
var _errors: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_d130_cast_review: --headless has no renderer; run under xvfb-run")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pool="):
			_pool = arg.trim_prefix("--pool=")
	if not POOLS.has(_pool):
		push_error("render_d130_cast_review: unknown pool %s (%s)" % [_pool, POOLS.keys()])
		quit(2)
		return
	for id: Variant in POOLS[_pool]:
		if ResourceLoader.exists(Spec.scene_path(String(id))):
			_chars.append(String(id))
		else:
			_errors += 1
			push_error("render_d130_cast_review: no scene for %s" % id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_stage()
	await _sheet()
	await _lineup()
	quit(1 if _errors > 0 else 0)


func _sheet() -> void:
	var band_h: int = TILE.y * 2 + HEAD_TILE.y
	var bands: int = ceili(float(_chars.size()) / COLS)
	var sheet: Image = Image.create(TILE.x * COLS, band_h * bands, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.2, 0.2))
	for c: int in range(_chars.size()):
		var x: int = TILE.x * (c % COLS)
		var y0: int = band_h * (c / COLS)
		var body: Node3D = (load(Spec.scene_path(_chars[c])) as PackedScene).instantiate() as Node3D
		CrowdLod.force_level(body, false)
		_vp.add_child(body)
		var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
		_pose(player, "humanoid/idle", 0.0, _chars[c])
		var head: Node3D = body.find_child("Head", true, false) as Node3D
		await process_frame
		var hz: Vector3 = head.global_position if head != null else Vector3(0.0, 1.6, 0.0)
		_label.text = _short(_chars[c])
		_label.visible = true
		_vp.size = TILE
		var front: Image = await _grab(_view(Vector3(0.0, 1.0, -3.6), Vector3(0.0, 0.9, 0.0)))
		sheet.blit_rect(front, Rect2i(Vector2i.ZERO, TILE), Vector2i(x, y0))
		_label.visible = false
		_pose(player, "humanoid/walk", WALK_T, _chars[c])
		var back: Image = await _grab(_view(Vector3(2.4, 1.3, 2.6), Vector3(0.0, 0.9, 0.0)))
		sheet.blit_rect(back, Rect2i(Vector2i.ZERO, TILE), Vector2i(x, y0 + TILE.y))
		_pose(player, "humanoid/idle", 0.0, _chars[c])
		_vp.size = HEAD_TILE
		var face: Image = await _grab(_view(hz + Vector3(-0.35, 0.05, -0.75), hz + Vector3(0.0, -0.05, 0.0)))
		sheet.blit_rect(face, Rect2i(Vector2i.ZERO, HEAD_TILE), Vector2i(x, y0 + TILE.y * 2))
		body.queue_free()
		await process_frame
	_save(sheet, _pool + "_sheet.png")


## Everyone in a row (front towards -Z, the camera) seen from LINEUP_DIST metres: the meshes keep their visibility
## ranges, so each character shows the LOD it would show at 30 m in game.
func _lineup() -> void:
	var bodies: Array[Node3D] = []
	var x0: float = -0.5 * LINEUP_SPACING * float(_chars.size() - 1)
	for c: int in range(_chars.size()):
		var body: Node3D = (load(Spec.scene_path(_chars[c])) as PackedScene).instantiate() as Node3D
		body.position = Vector3(-(x0 + LINEUP_SPACING * c), 0.0, 0.0)  # the camera looks along +Z: a left to right
		_vp.add_child(body)
		var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
		_pose(player, "humanoid/idle", 0.0, _chars[c])
		bodies.append(body)
	_label.visible = false
	_vp.size = LINEUP_SIZE
	var half_w: float = -x0 + 0.8
	var vfov: float = rad_to_deg(2.0 * atan(half_w / LINEUP_DIST * float(LINEUP_SIZE.y) / float(LINEUP_SIZE.x)))
	_cam.fov = vfov
	var eye: Vector3 = Vector3(0.0, 1.7, -LINEUP_DIST)
	var img: Image = await _grab(_view(eye, Vector3(0.0, 1.0, 0.0)))
	_save(img, _pool + "_lineup_30m.png")
	var black: StandardMaterial3D = StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.0, 0.0, 0.0)
	for body: Node3D in bodies:
		for n: Node in body.find_children("*", "MeshInstance3D", true, false):
			(n as MeshInstance3D).material_override = black
	img = await _grab(_view(eye, Vector3(0.0, 1.0, 0.0)))
	_save(img, _pool + "_silhouette_30m.png")
	for body: Node3D in bodies:
		body.queue_free()
	_cam.fov = 40.0


func _short(id: String) -> String:
	var s: String = id.trim_prefix("char_").replace("npc_", "").replace("gallery_", "")
	return s.replace("northgate_guard", "ng").replace("security_officer", "sec")


func _save(img: Image, file: String) -> void:
	var err: Error = img.save_png(OUT_DIR + file)
	if err != OK:
		_errors += 1
		push_error("render_d130_cast_review: could not save %s (%s)" % [file, error_string(err)])
	else:
		print("render_d130_cast_review: wrote %s%s" % [OUT_DIR, file])


func _pose(player: AnimationPlayer, clip: String, t: float, who: String) -> void:
	if not player.has_animation(clip):
		_errors += 1
		push_error("render_d130_cast_review: %s has no %s" % [who, clip])
		return
	player.play(clip)
	player.seek(t, true)
	player.pause()


func _stage() -> void:
	_vp = SubViewport.new()
	_vp.size = TILE
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
	env.environment.ambient_light_energy = 0.6
	_vp.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, 160.0, 0.0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	_vp.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -30.0, 0.0)
	fill.light_energy = 0.5
	_vp.add_child(fill)
	var vis: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40.0, 12.0)
	vis.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.48, 0.5)
	vis.material_override = mat
	_vp.add_child(vis)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, 2.02, 0.0)
	_label.pixel_size = 0.0025
	_label.font_size = 40
	_label.outline_size = 8
	_label.modulate = Color(1.0, 1.0, 1.0)
	_vp.add_child(_label)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.far = 200.0
	_vp.add_child(_cam)
	_cam.current = true


func _view(eye: Vector3, target: Vector3) -> Transform3D:
	return Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP).translated(eye)


func _grab(view: Transform3D) -> Image:
	_cam.global_transform = view
	for i: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
