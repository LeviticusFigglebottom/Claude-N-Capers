## PO6-17b (ui_hud v1.15): LocalHudModel.flashed_s whites out the screen (over the HUD), fading with the value and
## counting down smoothly between model polls.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")

var _hud: Hud
var _model: MockHudModel


func before_each() -> void:
	_model = MockHudModel.new()
	add_child(_model)
	_hud = HUD_SCENE.instantiate() as Hud
	_hud.auto_find_model = false
	add_child(_hud)
	await wait_frames(1)
	_hud.bind(_model)


func after_each() -> void:
	_hud.queue_free()
	_model.queue_free()
	await wait_frames(2)


func test_flash_whites_out_then_fades() -> void:
	var f: BreachFlash = _hud.breach_flash
	assert_true(f != null and _hud.widgets().has(f))
	assert_false(f.visible, "no flash at rest")
	_model.flashed_s = 2.5
	await wait_frames(1)
	assert_true(f.visible)
	assert_near(f.rect.color.a, f.tweak.flash_max_alpha, 0.01, "full white-out at the blast")
	assert_eq(f.get_index(), _hud.breach_flash.get_parent().get_child_count() - 1, "drawn over the rest of the HUD")
	await wait_seconds(1.4)
	assert_true(f.left_s < 1.3 and f.left_s > 0.8, "counts down between polls (%.2f)" % f.left_s)
	var mid: float = f.rect.color.a
	assert_true(mid < f.tweak.flash_max_alpha and mid > 0.2, "fading (%.2f)" % mid)
	_model.flashed_s = 0.0
	await wait_frames(1)
	assert_false(f.visible, "gone at 0")


func test_alpha_curve() -> void:
	var f: BreachFlash = _hud.breach_flash
	assert_near(f.alpha_for(5.0), f.tweak.flash_max_alpha, 0.001)
	assert_near(f.alpha_for(0.0), 0.0, 0.001)
	assert_true(f.alpha_for(0.5) < f.alpha_for(1.0))
