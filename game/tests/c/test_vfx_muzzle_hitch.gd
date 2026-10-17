## PO bug (Dockside Burn): NPC muzzle flashes froze in the air and never went away. A tick whose delta was longer than
## FLASH_S, before any frame had drawn the flash (low fps or a hitch), left `_left` <= 0 with the flash still shown,
## and every later tick returned early. Sets, sparks and lights must all clear once a frame is drawn. Headless:
## VfxSettings.test_frames stands in for Engine.get_frames_drawn().
extends TestCase

var _fx: MuzzleFx
var _lights: VfxLights


func before_each() -> void:
	VfxSettings.reset()
	GameRng.begin_run(130)
	VfxSettings.test_frames = 10
	_fx = MuzzleFx.new()
	add_child(_fx)
	_lights = VfxLights.new()
	add_child(_lights)


func after_each() -> void:
	for n: Node in [_fx, _lights]:
		if is_instance_valid(n):
			n.free()
	VfxSettings.reset()


func _visible_sets() -> int:
	var n: int = 0
	for c: Node in _fx.get_children():
		var mf: MuzzleFlash = c as MuzzleFlash
		if mf != null and (mf.is_flashing() or (mf.get_node("Sparks") as Node3D).visible):
			n += 1
	return n


func _fire_volley(count: int) -> void:
	for i: int in range(count):
		var origin: Vector3 = Vector3(float(i) * 1.5, 1.4, 0.0)
		_fx.fire(origin, Vector3.FORWARD, [&"rifle", &"pistol", &"shotgun", &"smg"][i % 4], false)
		_lights.flash(origin, MuzzleFx.LIGHT_COLOR, MuzzleFx.LIGHT_ENERGY, MuzzleFx.LIGHT_RANGE_M, MuzzleFx.LIGHT_S,
			MuzzleFx.LIGHT_END_COLOR, MuzzleFx.LIGHT_FALLOFF)


## A frame longer than the flash, before it was drawn: it must still show that frame, then clear after it.
func test_long_frame_before_draw_then_clears() -> void:
	_fire_volley(6)
	assert_eq(_visible_sets(), 6, "six flashes up")
	_fx.advance(0.2)  # the firing frame itself is long (5 fps)
	_lights.advance(0.2)
	assert_eq(_visible_sets(), 6, "not drawn yet: still up")
	_fx.advance(0.2)
	assert_eq(_visible_sets(), 6, "still no frame drawn: held, not dropped")
	VfxSettings.test_frames = 11  # one frame drawn
	for i: int in range(8):
		_fx.advance(0.016)
		_lights.advance(0.016)
	assert_eq(_visible_sets(), 0, "every set hidden once a frame has drawn them")
	assert_eq(_lights.live(), 0, "every muzzle light off")


## The 17 s npc_gunner hitch (ENV A): a flash fired right before a multi-second frame.
func test_multi_second_hitch() -> void:
	_fire_volley(4)
	_fx.advance(17.0)
	_lights.advance(17.0)
	VfxSettings.test_frames = 11
	for i: int in range(60):
		_fx.advance(1.0 / 60.0)
		_lights.advance(1.0 / 60.0)
	assert_eq(_visible_sets(), 0, "hidden after the hitch")
	assert_eq(_lights.live(), 0, "lights off after the hitch")


## Normal frame rate: a flash lasts about FLASH_S and at least one drawn frame.
func test_normal_rate_still_short() -> void:
	_fire_volley(1)
	for i: int in range(6):
		VfxSettings.test_frames += 1
		_fx.advance(1.0 / 60.0)
	var mf: MuzzleFlash = _fx.get_child(0) as MuzzleFlash
	assert_false(mf.is_flashing(), "flash gone within 0.1 s at 60 fps")
