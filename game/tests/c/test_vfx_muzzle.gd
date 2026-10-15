## D-113 muzzle flash (MuzzleFlash / MuzzleFx): class shapes, atlas variants, sparks, wisp, suppressed, the FP
## contract (flash / burst_end / fp_scale / tick, child names), determinism with a fixed GameRng seed. Headless.
extends TestCase

var _mf: MuzzleFlash


func before_each() -> void:
	VfxSettings.reset()
	GameRng.begin_run(99)
	_mf = (load("res://world/vfx/muzzle_flash.tscn") as PackedScene).instantiate() as MuzzleFlash
	_mf.auto_tick = false
	add_child(_mf)


func after_each() -> void:
	if is_instance_valid(_mf):
		_mf.free()
	_mf = null
	VfxSettings.reset()


func test_contract_children() -> void:
	for n: String in ["Star", "Flame", "Petals", "Sparks", "Wisp", "Smoke"]:
		assert_true(_mf.has_node(n), "child %s" % n)
	assert_true(_mf.has_method(&"burst_end") and _mf.has_method(&"fp_scale") and _mf.has_method(&"tick"))


func test_class_shapes() -> void:
	var cone: Dictionary[StringName, float] = {}
	for cls: StringName in [&"pistol", &"smg", &"rifle", &"lmg", &"shotgun", &"sniper"]:
		_mf.flash(1.0, false, cls, 0)
		assert_eq(_mf.last_shape, cls)
		assert_eq(_mf.petal_count(), int(MuzzleFlash.SHAPES[cls]["petals"]), "%s petals" % cls)
		cone[cls] = _mf.cone_length()
		_mf.hide_flash()
	assert_true(cone[&"sniper"] > cone[&"rifle"] and cone[&"rifle"] > cone[&"pistol"], "cone lengths %s" % cone)
	assert_true(cone[&"shotgun"] < cone[&"rifle"], "shotgun: short")
	_mf.flash(1.0, false, &"shotgun", 0)
	assert_true(_mf.get_node("Flame").scale.x > 0.6 * MuzzleFlash.SIZE_K, "shotgun: wide")
	assert_true(_mf.petal_count() > 4, "shotgun: more petals")
	assert_eq(MuzzleFlash.shape_of(&""), &"rifle", "&\"\" = rifle")
	assert_eq(MuzzleFlash.shape_of(&"assault_rifle"), &"rifle")
	assert_eq(MuzzleFlash.shape_of(&"melee_or_unknown"), &"rifle")


## PO6-13 / D-114 §8: toned down (half-ish size and duration) and long guns emit side jets from a brake.
func test_po6_13_toned_down_with_brake_ports() -> void:
	assert_true(MuzzleFlash.FLASH_S <= 0.035, "flash 2 frames at 60 fps (was 3)")
	assert_true(MuzzleFlash.SIZE_K * MuzzleFlash.BRAKE_CONE_K <= 0.5, "long-gun flash roughly halved")
	assert_true(MuzzleFx.LIGHT_ENERGY <= 2.5 and MuzzleFx.LIGHT_S <= 0.04, "light roughly halved")
	_mf.flash(1.0, false, &"rifle", 0)
	assert_true(_mf.last_brake, "rifle has a brake by default")
	assert_eq(_mf.port_count(), 2, "two side-port jets")
	var braked: float = _mf.cone_length()
	_mf.hide_flash()
	_mf.flash(1.0, false, &"rifle", 0, 0)
	assert_eq(_mf.port_count(), 0, "bare muzzle: no ports")
	assert_true(_mf.cone_length() > braked, "brake shortens the forward cone")
	_mf.hide_flash()
	_mf.flash(1.0, false, &"pistol", 0)
	assert_false(_mf.last_brake, "pistols have no brake")
	assert_eq(_mf.port_count(), 0)
	_mf.hide_flash()
	_mf.flash(1.0, true, &"rifle", 0)
	assert_eq(_mf.port_count(), 0, "suppressed: no ports")


func test_variants_use_the_atlas() -> void:
	_mf.flash(1.0, false, &"rifle", 2)
	assert_eq(_mf.last_variant, 2)
	var front: MeshInstance3D = _mf.get_node("Petals/Front") as MeshInstance3D
	var m: StandardMaterial3D = front.material_override as StandardMaterial3D
	assert_eq(m.albedo_texture, VfxTextures.muzzle_atlas(), "atlas texture")
	var r: Rect2 = VfxTextures.muzzle_uv(VfxTextures.MUZZLE_ROW_FRONT, 2)
	assert_near(m.uv1_offset.x, r.position.x, 0.0001, "cell offset")
	assert_eq(VfxTextures.muzzle_atlas().get_width(), VfxTextures.MUZZLE_CELL * VfxTextures.MUZZLE_VARIANTS)
	var seen: Dictionary[int, bool] = {}
	for i: int in range(40):
		_mf.flash(1.0, false, &"rifle")
		seen[_mf.last_variant] = true
	assert_eq(seen.size(), VfxTextures.MUZZLE_VARIANTS, "random variants cover the atlas")


func test_deterministic_with_fixed_seed() -> void:
	var a: Array = _sequence()
	var b: Array = _sequence()
	assert_eq(str(a), str(b), "same seed, same flashes")


func _sequence() -> Array:
	GameRng.begin_run(4242)
	var out: Array = []
	for i: int in range(5):
		_mf.flash(1.0, false, &"lmg")
		out.append([_mf.last_variant, snappedf(_mf.cone_length(), 0.0001), snappedf(_mf.get_node("Flame").rotation.z, 0.0001)])
	return out


func test_flash_sparks_wisp_lifecycle() -> void:
	_mf.flash(1.0, false, &"rifle", 0)
	assert_true(_mf.is_flashing(), "flash up")
	assert_true((_mf.get_node("Sparks") as Node3D).visible, "sparks")
	_mf.tick(MuzzleFlash.FLASH_S + 0.01)
	assert_false(_mf.is_flashing(), "flash gone after FLASH_S (headless never waits for a drawn frame)")
	_mf.tick(0.01)
	assert_true(_mf.is_wisp_visible(), "per-shot wisp starts after the flash")
	for i: int in range(5):
		_mf.tick(0.1)
	assert_false((_mf.get_node("Sparks") as Node3D).visible, "sparks are brief")
	for i: int in range(10):
		_mf.tick(0.1)
	assert_false(_mf.is_wisp_visible(), "wisp gone within 1.2 s")
	_mf.auto_wisp = false
	_mf.flash(1.0, false, &"pistol", 1)
	_mf.tick(0.1)
	assert_false(_mf.is_wisp_visible(), "auto_wisp off: no wisp until burst_end")
	_mf.burst_end()
	assert_true(_mf.is_wisp_visible(), "burst_end plays the wisp")
	var puff: Node3D = _mf.get_node("Wisp/Puff0") as Node3D
	var y0: float = puff.global_position.y
	_mf.tick(0.3)
	assert_true(puff.global_position.y > y0, "wisp rises")


func test_fp_scale_shrinks_sparks() -> void:
	_mf.flash(1.0, false, &"rifle", 0)
	var normal_len: float = _mf._spark_len[0]
	_mf.fp_scale(true)
	GameRng.begin_run(99)
	_mf.flash(1.0, false, &"rifle", 0)
	assert_true(_mf._spark_len[0] < normal_len, "first person: smaller sparks")


func test_suppressed_is_puff_only_and_no_light() -> void:
	_mf.flash(1.0, true, &"rifle")
	assert_false(_mf.is_flashing(), "no flash")
	assert_false((_mf.get_node("Sparks") as Node3D).visible, "no sparks")
	assert_true((_mf.get_node("Smoke") as Node3D).visible, "small grey puff")
	var d: VfxDirector = VfxDirector.new()
	d.listen_to_event_bus = false
	d.use_game_settings = false
	d.auto_advance = false
	d.play_impact_cues = false
	add_child(d)
	d.on_shot_fx(Vector3(0, 1, 0), Vector3(0, 1, -30), Vector3.ZERO, &"", &"assault_rifle", 3, VfxDirector.FLAG_SUPPRESSED)
	assert_eq(d.lights.started, 0, "suppressed: no light")
	d.advance(0.5)
	d.on_shot_fx(Vector3(0, 1, 0), Vector3(0, 1, -30), Vector3.ZERO, &"", &"shotgun", 3, 0)
	assert_eq(d.lights.started, 1, "unsuppressed: one light")
	assert_eq((d.muzzles._sets[d.muzzles._cursor] as MuzzleFlash).last_shape, &"shotgun", "TP flash uses the class shape")
	d.advance(MuzzleFx.LIGHT_S * 0.5)
	var l: OmniLight3D = d.lights.get_child(0) as OmniLight3D
	assert_true(l.light_energy < MuzzleFx.LIGHT_ENERGY * 0.5, "fast pulse: energy falls faster than linear")
	assert_true(l.light_color.g < MuzzleFx.LIGHT_COLOR.g, "cools toward orange")
	d.free()
