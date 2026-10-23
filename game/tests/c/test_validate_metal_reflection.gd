## validate_level `metal_reflection` (final): a metal surface with no reflection source renders black
## (environment reflections disabled, no ReflectionProbe or baked VoxelGI over it).
extends LcTestBase

const ONLY: PackedStringArray = ["metal_reflection"]


func _env(m: HeistMap, source: Environment.ReflectionSource) -> void:
	for n: Node in m.find_children("*", "WorldEnvironment", true, false):
		n.get_parent().remove_child(n)
		n.free()
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "TestEnv"
	we.environment = Environment.new()
	we.environment.reflected_light_source = source
	m.add_child(we)


func _metal_box(m: HeistMap, nm: String, mat: BaseMaterial3D) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	mi.mesh = BoxMesh.new()
	mi.material_override = mat
	mi.position = Vector3(5.0, 0.5, 2.0)
	m.get_node("Props").add_child(mi)


func _steel(nm: String) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.resource_name = nm
	mat.metallic = 1.0
	return mat


func _probe(m: HeistMap, mode: ReflectionProbe.UpdateMode) -> void:
	var rp: ReflectionProbe = ReflectionProbe.new()
	rp.size = Vector3(4, 3, 4)
	rp.position = Vector3(5.0, 1.5, 2.0)
	rp.update_mode = mode
	m.add_child(rp)


func test_bare_metal_fails() -> void:
	var res: Dictionary = await _validate(GOOD, "final", func(m: HeistMap) -> void:
		_env(m, Environment.REFLECTION_SOURCE_DISABLED)
		_metal_box(m, "BareSteel", _steel("lc_test_steel")), false, ONLY)
	_expect_fail(res, "metal_reflection", "lc_test_steel")


func test_probe_or_environment_reflections_pass() -> void:
	var probed: Dictionary = await _validate(GOOD, "final", func(m: HeistMap) -> void:
		_env(m, Environment.REFLECTION_SOURCE_DISABLED)
		_metal_box(m, "ProbedSteel", _steel("lc_test_steel"))
		_probe(m, ReflectionProbe.UPDATE_ONCE), false, ONLY)
	assert_eq(probed["metal_reflection"], PackedStringArray())
	var sky: Dictionary = await _validate(GOOD, "final", func(m: HeistMap) -> void:
		_env(m, Environment.REFLECTION_SOURCE_SKY)
		_metal_box(m, "SkySteel", _steel("lc_test_steel")), false, ONLY)
	assert_eq(sky["metal_reflection"], PackedStringArray())


func test_orm_blue_channel_drives_metalness() -> void:
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(1.0, 0.6, 0.0))  # ao 1, roughness 0.6, metallic 0
	var orm: ORMMaterial3D = ORMMaterial3D.new()
	orm.resource_name = "lc_test_painted"
	orm.metallic = 1.0
	orm.orm_texture = ImageTexture.create_from_image(img)
	var res: Dictionary = await _validate(GOOD, "final", func(m: HeistMap) -> void:
		_env(m, Environment.REFLECTION_SOURCE_DISABLED)
		_metal_box(m, "PaintedBox", orm), false, ONLY)
	assert_eq(res["metal_reflection"], PackedStringArray())
	assert_near(LcCheckMetalReflection.channel_mean(orm.orm_texture, BaseMaterial3D.TEXTURE_CHANNEL_BLUE), 0.0, 0.01)
	assert_near(LcCheckMetalReflection.channel_mean(orm.orm_texture, BaseMaterial3D.TEXTURE_CHANNEL_GREEN), 0.6, 0.01)
