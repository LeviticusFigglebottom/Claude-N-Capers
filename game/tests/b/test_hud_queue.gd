## Lead queue (c) / (d): the assault phase strip and the equipment chips on the HUD.
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
	await wait_frames(1)


## Lead queue (d): equipment as glyph + count chips; an item you don't carry is hidden, 0 is dimmed.
func test_equipment_chips() -> void:
	_model.masked = true
	_model.casing = false
	_model.deployable_id = &"deployable.doctor_bag"
	_model.deployable_count = 2
	_model.throwable_id = &""
	_model.cable_ties = 0
	_model.body_bags = 1
	var c: Dictionary = _hud.ammo.chips
	assert_eq((c[&"deployable"]["icon"] as EquipmentIcon).kind, &"doctor_bag")
	assert_eq((c[&"deployable"]["count"] as Label).text, "2")
	assert_false((c[&"throwable"]["box"] as Control).visible, "no throwable carried")
	assert_eq((c[&"cable_ties"]["count"] as Label).get_theme_color(&"font_color"), UiTokens.PAPER_DIM, "0 is dimmed")
	assert_eq(EquipmentIcon.kind_for(&"throwable.frag"), &"grenade")
	assert_eq(EquipmentIcon.kind_for(&"throwable.steady_flask"), &"vial")


## Lead queue (c): the assault phase strip lights the current phase; regrouping hides it and dims.
func test_assault_phase_strip() -> void:
	var b: AssaultBanner = _hud.assault
	_model.assault_phase = Enums.AssaultPhase.SUSTAIN
	assert_true(b.strip.visible)
	assert_eq(b.strip.current, 2, "anticipation | build | sustain | fade")
	_model.assault_phase = Enums.AssaultPhase.CONTROL
	assert_false(b.strip.visible)
	assert_true(b.panel.modulate.a < 1.0, "regrouping is quieter")
	_model.assault_phase = Enums.AssaultPhase.NONE
	assert_false(b.visible)


## Lead round 64: hostage count right of the banner; trade state while a crew member is in custody.
func test_hostage_strip_and_trade() -> void:
	var s: HostageStrip = _hud.hostages
	assert_false(s.visible, "no hostages, nobody in custody")
	_model.hostages = 2
	assert_true(s.visible)
	assert_eq(s.count_label.text, "2")
	assert_eq(s.trade, &"")
	_model.crew = [{"slot": 1, "name": "Dutch", "state": Enums.CrewState.CUSTODY}]
	assert_eq(s.trade, &"ready", "hostage + custody + no assault")
	_model.assault_phase = Enums.AssaultPhase.SUSTAIN
	assert_eq(s.trade, &"wait")
	_model.assault_phase = Enums.AssaultPhase.CONTROL
	assert_eq(s.trade, &"ready", "regrouping is the trade window")
	_model.hostages = 0
	assert_eq(s.trade, &"need")
	assert_true(s.visible, "the trade hint stays without hostages")


## Lead round 64: the Tab sheet lists bags secured by type with value, small loot and the total.
func test_scoreboard_loot_secured() -> void:
	var sb: ScoreboardOverlay = _hud.scoreboard
	sb.set_process(false)
	sb.set_shown(true)
	assert_eq(sb.loot_box.get_child_count(), 1, "'nothing secured yet'")
	EventBus.loot_secured.emit(11, &"loot.jewelry", 13000)
	EventBus.loot_secured.emit(12, &"loot.jewelry", 13000)
	EventBus.small_loot_taken.emit(1800, 0)
	assert_eq(sb.loot_secured[&"loot.jewelry"], {"count": 2, "value": 26000})
	await wait_frames(1)
	assert_eq(sb.loot_box.get_child_count(), 3, "jewelry, small loot, total")
	var total: HBoxContainer = sb.loot_box.get_child(2) as HBoxContainer
	assert_eq((total.get_child(1) as Label).text, UiText.money(27800))
