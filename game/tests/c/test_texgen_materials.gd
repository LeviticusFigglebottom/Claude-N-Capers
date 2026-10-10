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
	for id: String in EXPECTED:
		assert_has(ids, id, "library material missing")


func test_every_library_material_is_orm_pbr() -> void:
	var ids: Array[String] = _library_ids()
	assert_true(ids.size() >= EXPECTED.size(), "too few library materials")
	for id: String in ids:
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


func test_glass_is_transparent() -> void:
	var glass: ORMMaterial3D = load(MATERIAL_DIR + "glass_clear.tres") as ORMMaterial3D
	assert_true(glass != null, "glass_clear missing")
	if glass != null:
		assert_eq(glass.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "glass transparency")


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
