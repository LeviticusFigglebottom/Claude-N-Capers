## D-161 Hacker pocket ECM on the HUD (LEAD r289): the throwable chip shows the pocket ECM's charges with its own glyph
## and a caption (jam / feedback seconds while a charge runs, else the next charge's recharge). Binds to `pocket_ecm`
## (ui_hud v1.20 proposal: EcmSystem.pocket_state(local slot)); without it the chip is the plain throwable.
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
	_model.masked = true
	_model.casing = false


func after_each() -> void:
	_hud.queue_free()
	_model.queue_free()
	await wait_frames(1)


func _chip() -> Dictionary:
	return _hud.ammo.chips[&"throwable"] as Dictionary


func test_no_pocket_ecm_is_the_plain_throwable() -> void:
	_model.throwable_id = &"throwable.frag"
	_model.throwable_count = 3
	assert_eq((_chip()["icon"] as EquipmentIcon).kind, &"grenade")
	assert_eq((_chip()["count"] as Label).text, "3")
	assert_false(_hud.ammo.pocket_label.visible, "no caption without a pocket ECM")


func test_charges_and_recharge_caption() -> void:
	_model.throwable_id = &"throwable.frag"
	_model.pocket_ecm = {"charges": 1, "max": 2, "recharge_left": 37.2, "active_left": 0.0, "mode": &""}
	assert_true((_chip()["box"] as Control).visible)
	assert_eq((_chip()["icon"] as EquipmentIcon).kind, &"pocket_ecm", "the pocket ECM replaces the throwable")
	assert_eq((_chip()["count"] as Label).text, "1")
	assert_true(_hud.ammo.pocket_label.visible)
	assert_eq(_hud.ammo.pocket_label.text, UiText.t(&"ui.hud.pocket_ecm.recharge", {"s": 38}))
	_model.pocket_ecm = {"charges": 0, "max": 2, "recharge_left": 12.0, "active_left": 0.0, "mode": &""}
	assert_eq((_chip()["count"] as Label).get_theme_color(&"font_color"), UiTokens.PAPER_DIM, "no charge left: dimmed")
	_model.pocket_ecm = {"charges": 2, "max": 2, "recharge_left": 0.0, "active_left": 0.0, "mode": &""}
	assert_false(_hud.ammo.pocket_label.visible, "full: no caption")


func test_active_caption_per_mode() -> void:
	_model.pocket_ecm = {"charges": 1, "max": 2, "recharge_left": 100.0, "active_left": 4.3, "mode": &"jam"}
	assert_eq(_hud.ammo.pocket_label.text, UiText.t(&"ui.hud.pocket_ecm.jam", {"s": 5}), "a running jam wins")
	assert_eq(_hud.ammo.pocket_label.get_theme_color(&"font_color"), UiTokens.CYAN)
	_model.pocket_ecm = {"charges": 1, "max": 2, "recharge_left": 100.0, "active_left": 2.0, "mode": &"feedback"}
	assert_eq(_hud.ammo.pocket_label.text, UiText.t(&"ui.hud.pocket_ecm.feedback", {"s": 2}))
	assert_true(_hud.ammo.pocket_label.text.contains("FEEDBACK"))
	_model.pocket_ecm = {}
	assert_false(_hud.ammo.pocket_label.visible, "back to none")
