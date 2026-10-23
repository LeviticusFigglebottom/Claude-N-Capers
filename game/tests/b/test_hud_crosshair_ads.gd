## PO-22 (ui_hud v1.23, LocalHudModel.ads_blend): the crosshair fades out while aiming down sights, PD2-style; the
## masked / casing fade is unchanged.
extends TestCase

const HUD_PATH: String = "res://content/ui/hud/hud.tscn"

var _model: MockHudModel
var _hud: Hud


func after_each() -> void:
	for n: Node in [_hud, _model]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	await wait_frames(1)


func _spawn_hud() -> void:
	_model = MockHudModel.new()
	add_child(_model)
	_hud = (load(HUD_PATH) as PackedScene).instantiate() as Hud
	_hud.auto_find_model = false
	add_child(_hud)
	await wait_frames(1)
	_hud.bind(_model)


func test_crosshair_fades_in_ads() -> void:
	await _spawn_hud()
	_model.player_mode = &"masked"
	_model.ads_blend = 0.0
	await wait_seconds(0.6)
	assert_near(_hud.crosshair.modulate.a, 1.0, 0.01, "hip: visible")
	_model.ads_blend = 0.5
	await wait_frames(2)
	assert_near(_hud.crosshair.modulate.a, 0.5, 0.01, "half aimed: half faded")
	_model.ads_blend = 1.0
	await wait_frames(2)
	assert_near(_hud.crosshair.modulate.a, 0.0, 0.01, "ADS: hidden")
	_model.ads_blend = 0.0
	await wait_frames(2)
	assert_near(_hud.crosshair.modulate.a, 1.0, 0.01, "back to hip: visible at once")


func test_casing_stays_hidden_whatever_the_blend() -> void:
	await _spawn_hud()
	_model.player_mode = &"casing"
	_model.ads_blend = 0.0
	await wait_seconds(0.5)
	assert_near(_hud.crosshair.modulate.a, 0.0, 0.01, "no crosshair while casing")
