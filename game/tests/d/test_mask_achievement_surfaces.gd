## D-ACH: the achievement mask surfaces ENV D supplies for ENV B's MaskMaterialDef / MaskPatternDef
## (content/docs/masks.md): nine library materials (seven OF, two RT-D2; tools/blender/characters/make_materials.py,
## kinds in _mask_surfaces.py) and eight pattern textures (tools/blender/masks/make_mask_patterns.py) whose red channel is the
## pattern mask over mask UV0. Run after `godot --import`.
extends TestCase

const MATERIALS: Array[String] = [
	"char_mask_limestone", "char_mask_bronze", "char_mask_oil_canvas", "char_mask_container_rust",
	"char_mask_velvet_case", "char_mask_night_safe", "char_mask_gilt_leaf",
	"char_mask_armor_plate", "char_mask_hi_vis",  # RT-D2
]
const PATTERNS: Array[String] = ["guilloche", "vault_bolts", "acanthus", "facets", "time_lock_dial", "stencil",
	"road_lines", "tread"]
const PATTERN_DIR: String = "res://assets/masks/patterns/"
const PATTERN_SIZE: int = 1024
## Each colour of the pair must cover at least this share of the texture.
const MIN_SHARE: float = 0.15


func test_materials_load_with_textures() -> void:
	for id: String in MATERIALS:
		var path: String = "res://world/materials/%s.tres" % id
		var mat: BaseMaterial3D = load(path) as BaseMaterial3D
		assert_true(mat != null, "%s loads as a BaseMaterial3D" % path)
		if mat == null:
			continue
		assert_true(mat is ORMMaterial3D or mat is StandardMaterial3D, "%s is ORM/StandardMaterial3D" % id)
		assert_true(mat.albedo_texture != null, "%s has an albedo texture" % id)
		assert_true(mat.normal_enabled and mat.normal_texture != null, "%s has a normal map" % id)
		if mat is ORMMaterial3D:
			assert_true((mat as ORMMaterial3D).orm_texture != null, "%s has an ORM texture" % id)
		assert_eq(mat.resource_name, "M_" + id, "%s resource_name" % id)


func test_patterns_are_balanced_masks() -> void:
	for p: String in PATTERNS:
		var path: String = PATTERN_DIR + "tex_mask_pattern_%s.png" % p
		assert_true(ResourceLoader.exists(path), "%s exists (imported)" % path)
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			fail("%s does not load as a Texture2D" % path)
			continue
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		assert_eq(Vector2i(img.get_width(), img.get_height()), Vector2i(PATTERN_SIZE, PATTERN_SIZE), "%s size" % p)
		var low: int = 0
		var high: int = 0
		var n: int = 0
		for y: int in range(0, img.get_height(), 4):
			for x: int in range(0, img.get_width(), 4):
				var r: float = img.get_pixel(x, y).r
				if r < 0.1:
					low += 1
				elif r > 0.9:
					high += 1
				n += 1
		var share_a: float = float(low) / n
		var share_b: float = float(high) / n
		assert_true(share_a >= MIN_SHARE, "%s: colour A share %.3f >= %.2f" % [p, share_a, MIN_SHARE])
		assert_true(share_b >= MIN_SHARE, "%s: colour B share %.3f >= %.2f" % [p, share_b, MIN_SHARE])
		# anti-aliased: some edge texels sit between the two levels, but edges are thin
		var mid: float = 1.0 - share_a - share_b
		assert_true(mid > 0.0 and mid < 0.25, "%s: anti-aliased edge share %.3f in (0, 0.25)" % [p, mid])
