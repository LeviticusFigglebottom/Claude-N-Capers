## D-ACH: windowed review of the achievement mask materials (char_mask_limestone / bronze / oil_canvas /
## container_rust / velvet_case / night_safe / gilt_leaf) and pattern textures (tex_mask_pattern_guilloche /
## vault_bolts / acanthus / facets / time_lock_dial / stencil), each ON A MASK as the game composes it:
## MaskComposer.instantiate() on a MaskDef with an ENV D base glb, a colour pair from
## content/data/masks/parts/colors.tres, a review MaskMaterialDef wrapping the library .tres and a review
## MaskPatternDef with the texture_path. The review parts are added to MaskCatalog's in-memory cache only (nothing is
## saved; the part data is ENV B's). Owner: ENV D.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy \
##     --rendering-driver vulkan --path game res://world/characters/_tools/render_mask_achievement_review.tscn
##
## Vulkan (Forward+, the game's renderer; lavapipe under xvfb works): under `--rendering-driver opengl3`
## (Compatibility, llvmpipe) the mask shader's `detail_albedo` comes back un-linearised here, so lum/detail_mean
## saturates at the 1.4 clamp and every mask renders blown out with no grain.
##
## Writes to res://assets/masks/_review/achievement_surfaces/:
##   materials.png   one column per material: 3/4 close-up (solid colour A), front close-up, macro of the grain
##   patterns.png    rows = materials, columns = patterns (front 3/4 close-ups)
##   gameplay_2m.png the same grid seen from 2 m with a 70 degree camera at 1080p (what a player sees), 3x nearest
## and prints each material's measured mean albedo luminance (the shader's detail_mean: linear, 0.299/0.587/0.114).
## `-- --rt` (RT-D2, Rolling Thunder rewards) renders only rt_parts.png instead: row 1 the two bases (road_cone,
## ingot: front, 3/4, profile), row 2 the two materials on visage (armor_plate, hi_vis: front, 3/4, macro), row 3
## the two patterns (road_lines, tread) on visage, road_cone and ingot, row 4 the same at gameplay size (2 m).
## `-- --ah` (D-165, Afterhours rewards) renders only ah_parts.png: row 1 the two bases (vinyl in black satin, disco in
## sequin: front, 3/4, profile each), row 2 the sequin material on visage (front, 3/4, macro) and on disco / vinyl
## (3/4), row 3 the three dressed masks at gameplay size (2 m).
extends Node

const OUT_DIR: String = "res://assets/masks/_review/achievement_surfaces/"
const BASE_GLB: String = "res://assets/masks/mask_base_visage/mask_base_visage.glb"
## [library id, metallic, roughness, detail_strength, uv_tile, colour pair id, swap pair]
const MATERIALS: Array = [
	[&"char_mask_limestone", 0.0, 0.8, 0.8, 1.5, &"mask_colors.bone_ink", false],
	[&"char_mask_bronze", 1.0, 0.45, 0.8, 1.5, &"mask_colors.verdigris_crown", true],
	[&"char_mask_oil_canvas", 0.0, 0.62, 0.9, 1.5, &"mask_colors.harbor_fog", true],
	[&"char_mask_container_rust", 0.0, 0.8, 0.9, 1.5, &"mask_colors.ember_soot", false],
	[&"char_mask_velvet_case", 0.0, 0.9, 0.8, 1.5, &"mask_colors.velvet_vault", false],
	[&"char_mask_night_safe", 0.0, 0.5, 0.9, 1.5, &"mask_colors.black_crown", false],
	[&"char_mask_gilt_leaf", 1.0, 0.45, 0.8, 1.5, &"mask_colors.crown_ember", false],
	[&"char_mask_armor_plate", 1.0, 0.45, 0.9, 1.5, &"mask_colors.ghost_ledger", false],
	[&"char_mask_hi_vis", 0.0, 0.4, 0.8, 1.5, &"mask_colors.lantern_smoke", false],
]
const PATTERNS: Array[String] = ["guilloche", "vault_bolts", "acanthus", "facets", "time_lock_dial", "stencil",
	"road_lines", "tread"]
## --rt: the RT bases and the review rows that dress them ([glb, material row index, colour pair, swap])
const RT_CONE: String = "res://assets/masks/mask_base_road_cone/mask_base_road_cone.glb"
const RT_INGOT: String = "res://assets/masks/mask_base_ingot/mask_base_ingot.glb"
const RT_GOLD: Array = [&"char_mask_gilt_leaf", 1.0, 0.3, 0.0, 1.5, &"mask_colors.gilt_night", false]
## --ah: the Afterhours reward parts (D-165)
const AH_VINYL: String = "res://assets/masks/mask_base_vinyl/mask_base_vinyl.glb"
const AH_DISCO: String = "res://assets/masks/mask_base_disco/mask_base_disco.glb"
const AH_SEQUIN: Array = [&"char_mask_sequin", 0.85, 0.3, 0.9, 1.5, &"mask_colors.rose_cinder", false]
const AH_BLACK: Array = [&"char_mask_night_safe", 0.0, 0.35, 0.6, 1.5, &"mask_colors.black_crown", false]
const TILE: Vector2i = Vector2i(360, 400)

var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D
var _errors: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_mask_achievement_review: --headless has no renderer; run under xvfb-run")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var pairs: Dictionary = _colour_pairs()
	var solid: MaskPatternDef = MaskPatternDef.new()
	solid.id = &"mask_pattern.review_solid"
	solid.procedural = MaskPatternDef.Procedural.SOLID
	_register(MaskCatalog.PATTERN, solid)
	for p: String in PATTERNS:
		var pd: MaskPatternDef = MaskPatternDef.new()
		pd.id = StringName("mask_pattern.review_" + p)
		pd.texture_id = StringName("tex_mask_pattern_" + p)
		pd.texture_path = "res://assets/masks/patterns/tex_mask_pattern_%s.png" % p
		if not ResourceLoader.exists(pd.texture_path):
			_fail("missing pattern texture %s" % pd.texture_path)
		_register(MaskCatalog.PATTERN, pd)
	for row: Array in MATERIALS + [AH_SEQUIN]:
		var md: MaskMaterialDef = MaskMaterialDef.new()
		md.id = StringName("mask_material.review_" + String(row[0]))
		md.material_id = row[0]
		md.library_material = load("res://world/materials/%s.tres" % row[0]) as Material
		if md.library_material == null:
			_fail("missing library material %s" % row[0])
			continue
		md.metallic = row[1]
		md.roughness = row[2]
		md.detail_strength = row[3]
		md.uv_tile = row[4]
		md.detail_mean = _mean_lum(md.library_material as BaseMaterial3D)
		print("%s: detail_mean %.3f (metallic %.2f roughness %.2f detail_strength %.2f)" % [
			row[0], md.detail_mean, md.metallic, md.roughness, md.detail_strength])
		_register(MaskCatalog.MATERIAL, md)
	_stage()
	var base: PackedScene = load(BASE_GLB) as PackedScene
	if "--rt" in OS.get_cmdline_user_args():
		await _rt_sheet(base, pairs)
		get_tree().quit(1 if _errors > 0 else 0)
		return
	if "--ah" in OS.get_cmdline_user_args():
		await _ah_sheet(base, pairs)
		get_tree().quit(1 if _errors > 0 else 0)
		return
	# materials sheet: 3 rows (3/4, front, macro) x 4 materials
	var sheet: Image = Image.create(TILE.x * MATERIALS.size(), TILE.y * 3, false, Image.FORMAT_RGBA8)
	for c: int in range(MATERIALS.size()):
		var row: Array = MATERIALS[c]
		_show(_def(base, row, pairs, &"mask_pattern.review_solid"))
		var views: Array = [[0.45, 35.0, 12.0, 30.0], [0.40, 0.0, 0.0, 30.0], [0.13, 20.0, 5.0, 30.0]]
		for r: int in range(views.size()):
			var v: Array = views[r]
			sheet.blit_rect(await _grab(float(v[0]), float(v[1]), float(v[2]), float(v[3])),
				Rect2i(Vector2i.ZERO, TILE), Vector2i(c * TILE.x, r * TILE.y))
	_save(sheet, "materials.png")
	# patterns sheet: rows = materials, cols = patterns
	var pats: Image = Image.create(TILE.x * PATTERNS.size(), TILE.y * MATERIALS.size(), false, Image.FORMAT_RGBA8)
	var game: Image = Image.create(TILE.x * PATTERNS.size(), TILE.y * MATERIALS.size(), false, Image.FORMAT_RGBA8)
	for r: int in range(MATERIALS.size()):
		for c: int in range(PATTERNS.size()):
			_show(_def(base, MATERIALS[r], pairs, StringName("mask_pattern.review_" + PATTERNS[c])))
			pats.blit_rect(await _grab(0.42, 20.0, 6.0, 30.0), Rect2i(Vector2i.ZERO, TILE),
				Vector2i(c * TILE.x, r * TILE.y))
			game.blit_rect(await _grab_gameplay(), Rect2i(Vector2i.ZERO, TILE), Vector2i(c * TILE.x, r * TILE.y))
	_save(pats, "patterns.png")
	_save(game, "gameplay_2m.png")
	get_tree().quit(1 if _errors > 0 else 0)


## RT-D2: the Rolling Thunder reward parts on one sheet (see the header).
func _rt_sheet(visage: PackedScene, pairs: Dictionary) -> void:
	var cone: PackedScene = load(RT_CONE) as PackedScene
	var ingot: PackedScene = load(RT_INGOT) as PackedScene
	if cone == null or ingot == null:
		_fail("missing RT base glb")
		return
	var plate: Array = MATERIALS[MATERIALS.size() - 2]
	var vis: Array = MATERIALS[MATERIALS.size() - 1]
	var lines_row: Array = [&"char_mask_night_safe", 0.0, 0.5, 0.9, 1.5, &"mask_colors.bone_ink", true]
	var sheet: Image = Image.create(TILE.x * 6, TILE.y * 4, false, Image.FORMAT_RGBA8)
	var views: Array = [[0.40, 0.0, 0.0, 34.0], [0.45, 35.0, 12.0, 34.0], [0.45, 80.0, 5.0, 34.0]]
	var col: int = 0
	for pair: Array in [[cone, vis], [ingot, RT_GOLD]]:
		_show(_def(pair[0], pair[1], pairs, &"mask_pattern.review_solid"))
		for v: Array in views:
			sheet.blit_rect(await _grab(float(v[0]), float(v[1]), float(v[2]), float(v[3])),
				Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, 0))
			col += 1
	col = 0
	var mviews: Array = [[0.40, 0.0, 0.0, 30.0], [0.45, 35.0, 12.0, 30.0], [0.13, 20.0, 5.0, 30.0]]
	for row: Array in [plate, vis]:
		_show(_def(visage, row, pairs, &"mask_pattern.review_solid"))
		for v: Array in mviews:
			sheet.blit_rect(await _grab(float(v[0]), float(v[1]), float(v[2]), float(v[3])),
				Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, TILE.y))
			col += 1
	col = 0
	for p: String in ["road_lines", "tread"]:
		for b: PackedScene in [visage, cone, ingot]:
			_show(_def(b, lines_row, pairs, StringName("mask_pattern.review_" + p)))
			sheet.blit_rect(await _grab(0.42, 20.0, 6.0, 32.0), Rect2i(Vector2i.ZERO, TILE),
				Vector2i(col * TILE.x, 2 * TILE.y))
			sheet.blit_rect(await _grab_gameplay(), Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, 3 * TILE.y))
			col += 1
	_save(sheet, "rt_parts.png")


## D-165: the Afterhours reward parts on one sheet (see the header).
func _ah_sheet(visage: PackedScene, pairs: Dictionary) -> void:
	var vinyl: PackedScene = load(AH_VINYL) as PackedScene
	var disco: PackedScene = load(AH_DISCO) as PackedScene
	if vinyl == null or disco == null:
		_fail("missing AH base glb")
		return
	var sheet: Image = Image.create(TILE.x * 6, TILE.y * 3, false, Image.FORMAT_RGBA8)
	var views: Array = [[0.40, 0.0, 0.0, 34.0], [0.45, 35.0, 12.0, 34.0], [0.45, 80.0, 5.0, 34.0]]
	var col: int = 0
	for pair: Array in [[vinyl, AH_BLACK], [disco, RT_GOLD]]:
		_show(_def(pair[0], pair[1], pairs, &"mask_pattern.review_solid"))
		for v: Array in views:
			sheet.blit_rect(await _grab(float(v[0]), float(v[1]), float(v[2]), float(v[3])),
				Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, 0))
			col += 1
	col = 0
	_show(_def(visage, AH_SEQUIN, pairs, &"mask_pattern.review_solid"))
	for v: Array in [[0.40, 0.0, 0.0, 30.0], [0.45, 35.0, 12.0, 30.0], [0.13, 20.0, 5.0, 30.0]]:
		sheet.blit_rect(await _grab(float(v[0]), float(v[1]), float(v[2]), float(v[3])),
			Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, TILE.y))
		col += 1
	for pair: Array in [[disco, AH_SEQUIN], [vinyl, AH_BLACK], [visage, AH_SEQUIN]]:
		_show(_def(pair[0], pair[1], pairs, &"mask_pattern.review_solid"))
		if col < 6:
			sheet.blit_rect(await _grab(0.42, 20.0, 6.0, 32.0), Rect2i(Vector2i.ZERO, TILE),
				Vector2i(col * TILE.x, TILE.y))
			col += 1
	col = 0
	for pair: Array in [[vinyl, AH_BLACK], [disco, AH_SEQUIN], [visage, AH_SEQUIN]]:
		_show(_def(pair[0], pair[1], pairs, &"mask_pattern.review_solid"))
		sheet.blit_rect(await _grab_gameplay(), Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, 2 * TILE.y))
		col += 1
	_save(sheet, "ah_parts.png")


func _def(base: PackedScene, row: Array, pairs: Dictionary, pattern: StringName) -> MaskDef:
	var d: MaskDef = MaskDef.new()
	d.id = &"mask.review"
	d.model = base
	d.material_id = row[0]
	var pair: Array = pairs.get(row[5], [Color.WHITE, Color.BLACK])
	d.color_a = pair[1] if bool(row[6]) else pair[0]
	d.color_b = pair[0] if bool(row[6]) else pair[1]
	d.pattern_id = pattern
	return d


func _colour_pairs() -> Dictionary:
	var out: Dictionary = {}
	for p: MaskPartDef in MaskCatalog.all_parts(MaskCatalog.COLORS):
		var c: MaskColorDef = p as MaskColorDef
		out[c.id] = [c.color_a, c.color_b]
	if out.is_empty():
		_fail("MaskCatalog has no colour pairs")
	return out


## Review-only part registration in MaskCatalog's in-memory cache (never saved).
func _register(kind: String, p: MaskPartDef) -> void:
	MaskCatalog.all_parts(kind)  # fills the cache
	MaskCatalog._by_id[p.id] = p
	(MaskCatalog._lists[kind] as Array).append(p)


## Mean albedo luminance as the mask shader sees it (linear after sRGB decode, 0.299/0.587/0.114).
func _mean_lum(mat: BaseMaterial3D) -> float:
	var img: Image = mat.albedo_texture.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	var sum: float = 0.0
	var n: int = 0
	for y: int in range(0, img.get_height(), 2):
		for x: int in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y).srgb_to_linear()
			sum += c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			n += 1
	return sum / maxf(n, 1)


func _show(def: MaskDef) -> void:
	for ch: Node in _holder.get_children():
		ch.queue_free()
	var m: Node3D = MaskComposer.instantiate(def)
	_holder.add_child(m)


func _stage() -> void:
	_vp = SubViewport.new()
	_vp.size = TILE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.30, 0.31, 0.33)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment.ambient_light_energy = 0.25
	env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_vp.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 200.0, 0.0)
	key.light_energy = 0.8
	_vp.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10.0, 140.0, 0.0)
	fill.light_energy = 0.25
	_vp.add_child(fill)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 20.0, 0.0)
	rim.light_energy = 0.3
	_vp.add_child(rim)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	_cam = Camera3D.new()
	_vp.add_child(_cam)
	_cam.current = true


## Camera on the mask's front (-Z) at `dist` m, orbited `yaw`/`pitch` degrees, vertical fov `fov`.
func _grab(dist: float, yaw: float, pitch: float, fov: float) -> Image:
	_cam.fov = fov
	var dir: Vector3 = Vector3(0.0, 0.0, -1.0).rotated(Vector3.RIGHT, deg_to_rad(pitch)).rotated(Vector3.UP, deg_to_rad(yaw))
	_cam.position = dir * dist
	_cam.look_at(Vector3.ZERO, Vector3.UP)
	return await _frame()


## Gameplay size: 2 m away, 70 degree vertical fov on a 1080 px tall screen, so the mask covers as many pixels as
## in play; rendered at that size and scaled 3x (nearest) into the tile.
func _grab_gameplay() -> Image:
	var px: int = int(round(TILE.y / 3.0))
	var full_h: float = 1080.0
	# a 1080 px tall 70 degree view, cropped to `px` pixels: the crop's fov
	var crop_fov: float = rad_to_deg(2.0 * atan(tan(deg_to_rad(35.0)) * px / full_h))
	_vp.size = Vector2i(int(round(TILE.x / 3.0)), px)
	_cam.fov = crop_fov
	var dir: Vector3 = Vector3(0.0, 0.0, -1.0).rotated(Vector3.RIGHT, deg_to_rad(5.0)).rotated(Vector3.UP, deg_to_rad(20.0))
	_cam.position = dir * 2.0
	_cam.look_at(Vector3.ZERO, Vector3.UP)
	var img: Image = await _frame()
	_vp.size = TILE
	img.resize(TILE.x, TILE.y, Image.INTERPOLATE_NEAREST)
	return img


func _frame() -> Image:
	for i: int in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(img: Image, file: String) -> void:
	var err: Error = img.save_png(OUT_DIR + file)
	if err != OK:
		_fail("cannot save %s (%d)" % [file, err])
	else:
		print("wrote %s%s" % [OUT_DIR, file])


func _fail(msg: String) -> void:
	_errors += 1
	push_error("render_mask_achievement_review: " + msg)
