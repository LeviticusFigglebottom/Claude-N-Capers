## r266 B top-3 #1: status text that must read on a bright scene sits on the strong label scrim
## (UiBuild.LABEL_SCRIM_STRONG_ALPHA). The contrast worker's fill gate measured, on the bright backdrop: the HEALTH
## caption 2.94:1, a teammate's "In custody" 1.99:1 and the DOWNED caption 1.27:1 before; all >= 3:1 after
## (tests/b/render/hud_contrast_capture.gd -- loud / hud). This pins the scrims headless.
extends TestCase

const HUD: PackedScene = preload("res://content/ui/hud/hud.tscn")

var _model: MockHudModel
var _hud: Hud


func before_each() -> void:
	_model = MockHudModel.new()
	add_child(_model)
	_hud = HUD.instantiate() as Hud
	_hud.auto_find_model = false
	add_child(_hud)
	await wait_frames(1)
	_hud.bind(_model)


func after_each() -> void:
	_hud.queue_free()
	_model.queue_free()
	await wait_frames(1)


func test_vitals_captions_sit_on_the_strong_scrim() -> void:
	var caps: Array[Label] = []
	for n: Node in _hud.vitals.find_children("*", "Label", true, false):
		var l: Label = n as Label
		if l.text in [UiText.t(&"ui.hud.armor"), UiText.t(&"ui.hud.health")]:
			caps.append(l)
	assert_eq(caps.size(), 2, "the ARMOR and HEALTH captions")
	for l: Label in caps:
		_assert_strong(l)


func test_teammate_status_line_sits_on_the_strong_scrim() -> void:
	_model.crew = [{"slot": 1, "name": "Dutch", "armor_frac": 1.0, "health_frac": 0.0, "state": Enums.CrewState.CUSTODY}]
	await wait_frames(2)
	var info: Label = null
	for n: Node in _hud.teammates.find_children("*", "Label", true, false):
		if (n as Label).text == UiText.t(&"ui.hud.custody"):
			info = n as Label
	assert_true(info != null and info.is_visible_in_tree(), "the teammate's In custody line shows")
	if info != null:
		_assert_strong(info)
	_model.crew = [{"slot": 1, "name": "Dutch", "armor_frac": 1.0, "health_frac": 1.0, "downs_left": 3}]
	await wait_frames(2)
	if info != null:
		assert_false(info.visible, "no empty scrim when there is no status")


func test_downed_caption_sits_on_the_strong_scrim() -> void:
	_assert_strong(_hud.downed.caption)
	assert_eq(_hud.downed.caption.size_flags_horizontal, Control.SIZE_SHRINK_CENTER, "the scrim hugs the word")


func _assert_strong(l: Label) -> void:
	var sb: StyleBoxFlat = l.get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_true(sb != null and is_equal_approx(sb.bg_color.a, UiBuild.LABEL_SCRIM_STRONG_ALPHA),
			"'%s' on the strong scrim (%s)" % [l.text, sb.bg_color if sb != null else "none"])
