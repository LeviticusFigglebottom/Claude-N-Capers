## ui_hud v1.21 / v1.22 (D-161, D-163, D-164): a deck throwable on the HUD, bound to `perk_item` (the pocket_ecm alias
## is gone). The throwable chip shows the item's glyph and charges with a caption (jam / feedback for the pocket ECM, the
## kind's own word or ACTIVE while it runs, else the recharge); the gas dispenser's partner gets a PAIRED tag on their
## teammate panel; a running leech ampule splits the health bar into its slices.
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


func _item(kind: StringName, charges: int, mx: int, cooldown: float, active: float, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"kind": kind, "charges": charges, "max": mx, "cooldown_left": cooldown, "active_left": active,
		"partner_slot": -1, "mode": &""}
	d.merge(extra, true)
	return d


func test_no_deck_item_is_the_plain_throwable() -> void:
	_model.throwable_id = &"throwable.frag"
	_model.throwable_count = 3
	assert_eq((_chip()["icon"] as EquipmentIcon).kind, &"grenade")
	assert_eq((_chip()["count"] as Label).text, "3")
	assert_false(_hud.ammo.pocket_label.visible, "no caption without a deck item")


func test_pocket_ecm_charges_mode_and_recharge() -> void:
	_model.throwable_id = &"throwable.pocket_ecm"
	_model.perk_item = _item(&"pocket_ecm", 1, 2, 37.2, 0.0)
	assert_eq((_chip()["icon"] as EquipmentIcon).kind, &"pocket_ecm")
	assert_eq((_chip()["count"] as Label).text, "1")
	assert_eq(_hud.ammo.pocket_label.text, UiText.t(&"ui.hud.perk_item.recharge", {"s": 38}))
	_model.perk_item = _item(&"pocket_ecm", 0, 2, 12.0, 0.0)
	assert_eq((_chip()["count"] as Label).get_theme_color(&"font_color"), UiTokens.PAPER_DIM, "no charge left: dimmed")
	_model.perk_item = _item(&"pocket_ecm", 1, 2, 100.0, 4.3, {"mode": &"jam"})
	assert_eq(_hud.ammo.pocket_label.text, UiText.t(&"ui.hud.perk_item.jam", {"s": 5}), "a running jam wins")
	assert_eq(_hud.ammo.pocket_label.get_theme_color(&"font_color"), UiTokens.CYAN)
	_model.perk_item = _item(&"pocket_ecm", 1, 2, 100.0, 2.0, {"mode": &"feedback"})
	assert_true(_hud.ammo.pocket_label.text.contains("FEEDBACK"))
	_model.perk_item = _item(&"pocket_ecm", 2, 2, 0.0, 0.0)
	assert_false(_hud.ammo.pocket_label.visible, "full: no caption")
	_model.perk_item = {}
	assert_false(_hud.ammo.pocket_label.visible, "back to none")


func test_every_deck_item_kind_has_a_glyph_and_caption() -> void:
	for kind: StringName in [&"smoke_bomb", &"gas_dispenser", &"leech_ampule", &"injector", &"flask"]:
		_model.perk_item = _item(kind, 1, 1, 0.0, 3.0)
		var glyph: StringName = (_chip()["icon"] as EquipmentIcon).kind
		assert_true(EquipmentIcon.KINDS.has(glyph), "%s draws %s" % [kind, glyph])
		assert_true(_hud.ammo.pocket_label.visible and _hud.ammo.pocket_label.text.contains("3"), "%s: %s" % [kind,
				_hud.ammo.pocket_label.text])
	_model.perk_item = _item(&"smoke_bomb", 1, 1, 0.0, 3.0)
	assert_eq(_hud.ammo.pocket_label.text, UiText.t(&"ui.hud.perk_item.smoke_bomb", {"s": 3}))
	_model.perk_item = _item(&"injector", 1, 1, 0.0, 3.0)
	assert_eq(_hud.ammo.pocket_label.text, UiText.t(&"ui.hud.perk_item.active", {"s": 3}), "no own word: ACTIVE")
	assert_eq((_chip()["icon"] as EquipmentIcon).kind, &"vial")


func test_paired_tag_on_the_partner_panel() -> void:
	var crew: Array[Dictionary] = []
	for slot: int in [1, 2]:
		crew.append({"slot": slot, "name": "P%d" % slot, "health_frac": 1.0, "armor_frac": 1.0,
			"state": Enums.CrewState.NORMAL, "downs_left": 3})
	_model.crew = crew
	await wait_frames(1)
	var tags: Dictionary = _hud.teammates.paired_labels
	assert_eq(tags.size(), 2)
	assert_false((tags[1] as Label).visible or (tags[2] as Label).visible, "nobody paired")
	_model.perk_item = _item(&"gas_dispenser", 0, 1, 60.0, 8.0, {"partner_slot": 2})
	assert_false((tags[1] as Label).visible)
	assert_true((tags[2] as Label).visible, "the tagged teammate says PAIRED")
	_model.perk_item = _item(&"gas_dispenser", 0, 1, 50.0, 0.0)
	assert_false((tags[2] as Label).visible, "pairing over")


func test_leech_slices_on_the_health_bar() -> void:
	var ticks: Control = _hud.vitals.segment_ticks
	assert_false(ticks.visible)
	_model.perk_item = _item(&"leech_ampule", 0, 1, 40.0, 6.0, {"segments": {"count": 4, "size": 5}})
	assert_true(ticks.visible, "5 slices while the ampule runs")
	_model.perk_item = _item(&"leech_ampule", 0, 1, 35.0, 0.0)
	assert_false(ticks.visible, "gone when it ends")
