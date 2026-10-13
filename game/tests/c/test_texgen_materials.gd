## ENV C texgen: material library v1 (tools/texgen) loads as ORM PBR materials, LUTs import as
## Texture3D, the Glasshouse environment is wired, and the trim sheet table is sane.
extends TestCase

const MATERIAL_DIR: String = "res://world/materials/"
const EXPECTED: Array[String] = [
	"plaster_painted", "drywall_painted", "concrete", "terrazzo", "marble_cream", "carpet_commercial",
	"ceiling_tile", "wood_veneer_walnut", "brushed_steel", "chrome", "brass", "glass_clear",
	"rubber_black", "fabric_upholstery", "leather_dark", "plastic_matte", "brick_red", "asphalt",
	"tile_ceramic_white", "vinyl_floor", "metal_painted", "trim_interior",
]
## First-person weapon materials (D-026): 1 UV unit = 1 m, 1024 px/m.
const WEAPON: Array[String] = [
	"polymer_black", "polymer_stipple", "steel_blued", "steel_bare", "metal_matte", "paint_white",
	"brass_cartridge", "glass_lens_tint", "alu_anodized_black", "polymer_tan", "polymer_olive",
	"glass_lens_coated", "paint_safety_orange", "carbon_fibre",
]
## Untextured by design: a reticle is a tiny emissive mesh; textures would add nothing.
const EMISSIVE: Array[String] = ["emissive_reticle_red", "emissive_pilot_flame"]
## D-038: black polymers, rubber and black paint/anodize may sit at 0.02-0.04 linear albedo.
const BLACKS: Array[String] = ["polymer_black", "polymer_stipple", "rubber_black", "alu_anodized_black"]
const TRIM_TABLE: String = "res://assets/textures/trim_interior/trim_table.json"


func _library_ids() -> Array[String]:
	var ids: Array[String] = []
	for f: String in DirAccess.get_files_at(MATERIAL_DIR):
		var file: String = f.trim_suffix(".remap")
		if file.ends_with(".tres") and not file.begins_with("grey_"):
			ids.append(file.get_basename())
	ids.sort()
	return ids


func test_expected_library_present() -> void:
	var ids: Array[String] = _library_ids()
	for id: String in EXPECTED + WEAPON + EMISSIVE:
		assert_has(ids, id, "library material missing")


func test_every_library_material_is_orm_pbr() -> void:
	var ids: Array[String] = _library_ids()
	assert_true(ids.size() >= EXPECTED.size() + WEAPON.size(), "too few library materials")
	for id: String in ids:
		# LEAD round 35: char_crowd_lod (ENV D, D4-01) is a shared skinned crowd-LOD material, not a library PBR.
		if id in EMISSIVE or id == "char_crowd_lod":
			continue
		var res: Resource = load(MATERIAL_DIR + id + ".tres")
		assert_true(res is ORMMaterial3D, "%s is not ORMMaterial3D" % id)
		var mat: ORMMaterial3D = res as ORMMaterial3D
		if mat == null:
			continue
		assert_true(mat.albedo_texture != null, "%s albedo texture null" % id)
		assert_true(mat.orm_texture != null, "%s orm texture null" % id)
		assert_true(mat.normal_enabled, "%s normal map disabled" % id)
		assert_true(mat.normal_texture != null, "%s normal texture null" % id)
		assert_true(mat.ao_enabled, "%s AO (ORM.r) disabled" % id)
		# ORM drives roughness/metallic only when the scalar multipliers are 1.
		assert_near(mat.metallic, 1.0, 0.0001, "%s metallic multiplier" % id)
		assert_near(mat.roughness, 1.0, 0.0001, "%s roughness multiplier" % id)
		assert_false(mat.uv1_triplanar, "%s must use mesh UVs, not triplanar" % id)
		assert_eq(String(mat.resource_name), "M_" + id, "resource_name")
		var tile_m: float = float(mat.get_meta(&"uv_tile_m", 0.0))
		assert_near(tile_m, 1.0 if id in WEAPON else 2.0, 0.0001, "%s uv_tile_m" % id)


func test_emissive_materials() -> void:
	for id: String in EMISSIVE:
		var mat: StandardMaterial3D = load(MATERIAL_DIR + id + ".tres") as StandardMaterial3D
		assert_true(mat != null, "%s is not a StandardMaterial3D" % id)
		if mat == null:
			continue
		assert_true(mat.emission_enabled, "%s emission" % id)
		assert_true(mat.emission_energy_multiplier >= 1.0, "%s must be bright enough to glow" % id)
		assert_eq(String(mat.resource_name), "M_" + id, "resource_name")
	var flame: StandardMaterial3D = load(MATERIAL_DIR + "emissive_pilot_flame.tres") as StandardMaterial3D
	if flame != null:
		assert_true(flame.emission_texture is GradientTexture2D, "pilot flame has its blue-orange gradient")


func test_carbon_fibre_clearcoat() -> void:
	var cf: ORMMaterial3D = load(MATERIAL_DIR + "carbon_fibre.tres") as ORMMaterial3D
	assert_true(cf != null, "carbon_fibre missing")
	if cf != null:
		assert_true(cf.clearcoat_enabled, "carbon fibre needs its clear coat")
		assert_true(cf.clearcoat_roughness <= 0.15, "clear coat is glossy")


func test_glass_is_transparent() -> void:
	for id: String in ["glass_clear", "glass_lens_tint", "glass_lens_coated"]:
		var glass: ORMMaterial3D = load(MATERIAL_DIR + id + ".tres") as ORMMaterial3D
		assert_true(glass != null, "%s missing" % id)
		if glass != null:
			assert_eq(glass.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "%s transparency" % id)


func test_luts_import_as_3d_textures() -> void:
	for lut_name: String in ["lut_neutral", "lut_glasshouse"]:
		var tex: Texture3D = load("res://assets/luts/%s.png" % lut_name) as Texture3D
		assert_true(tex != null, "%s is not a Texture3D (check .import importer=3d_texture)" % lut_name)
		if tex != null:
			assert_eq(tex.get_width(), 32, "%s width" % lut_name)
			assert_eq(tex.get_height(), 32, "%s height" % lut_name)
			assert_eq(tex.get_depth(), 32, "%s depth" % lut_name)


func test_glasshouse_environment() -> void:
	var env: Environment = load("res://world/lighting/env_glasshouse.tres") as Environment
	assert_true(env != null, "env_glasshouse missing")
	if env == null:
		return
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_AGX, "tonemapper")
	assert_true(env.ssao_enabled, "ssao")
	assert_true(env.ssil_enabled, "ssil")
	assert_true(env.glow_enabled, "glow")
	assert_true(env.adjustment_enabled, "adjustments")
	assert_true(env.adjustment_color_correction is Texture3D, "colour correction must be the 3D LUT")
	assert_true(env.sky != null and env.sky.sky_material is ProceduralSkyMaterial, "procedural sky")
	var sun_scene: PackedScene = load("res://world/lighting/sun_glasshouse.tscn") as PackedScene
	assert_true(sun_scene != null, "sun scene missing")
	if sun_scene != null:
		var sun: DirectionalLight3D = sun_scene.instantiate() as DirectionalLight3D
		assert_true(sun != null, "sun root is a DirectionalLight3D")
		if sun != null:
			var down: Vector3 = -sun.transform.basis.z
			assert_true(down.y < 0.0 and down.y > -0.3, "dusk sun is low and shines downward")
			sun.free()


func test_trim_table() -> void:
	var text: String = FileAccess.get_file_as_string(TRIM_TABLE)
	assert_false(text.is_empty(), "trim table missing")
	var data: Variant = JSON.parse_string(text)
	assert_true(data is Dictionary, "trim table is a JSON object")
	if not data is Dictionary:
		return
	var table: Dictionary = data as Dictionary
	assert_near(float(table["u_repeat_m"]), 2.0, 0.0001, "u repeat")
	var strips: Array = table["strips"] as Array
	assert_true(strips.size() >= 7, "trim strips")
	var last_bottom: float = 0.0
	for s: Variant in strips:
		var strip: Dictionary = s as Dictionary
		var top: float = float(strip["v_top_gltf"])
		var bottom: float = float(strip["v_bottom_gltf"])
		assert_true(top >= last_bottom and bottom > top and bottom <= 1.0, "strip %s range" % strip["name"])
		assert_near(float(strip["v_min_blender"]), 1.0 - bottom, 0.00001, "blender v flip")
		last_bottom = bottom


func _mean_linear_luminance(tex: Texture2D) -> float:
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	img.resize(32, 32, Image.INTERPOLATE_BILINEAR)
	var total: float = 0.0
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var c: Color = img.get_pixel(x, y).srgb_to_linear()
			total += c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	return total / float(img.get_width() * img.get_height())


func test_black_materials_read_black() -> void:
	for id: String in BLACKS:
		var mat: ORMMaterial3D = load(MATERIAL_DIR + id + ".tres") as ORMMaterial3D
		assert_true(mat != null, "%s missing" % id)
		if mat == null:
			continue
		var lum: float = _mean_linear_luminance(mat.albedo_texture)
		assert_true(lum >= 0.018 and lum <= 0.035, "%s mean albedo luminance %.4f not in black band" % [id, lum])
	var other: ORMMaterial3D = load(MATERIAL_DIR + "plastic_matte.tres") as ORMMaterial3D
	if other != null:
		assert_true(_mean_linear_luminance(other.albedo_texture) >= 0.038, "non-black materials keep the 0.04 floor")
