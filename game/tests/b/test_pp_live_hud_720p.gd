## PQ-B-14 (D-076): HUD + subtitle readability at 1280x720 in a LIVE heist (glasshouse via
## MenuFlow.direct_launch, real LocalHudModel). The canvas is 1080 units, so 1 unit = 720/1080 px.
## Every visible HUD label must render at >= MIN_HUD_PX real pixels, default subtitles at >= MIN_SUB_PX,
## all widgets on screen, always-on widgets never overlapping, subtitles clear of vitals / ammo.
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const PX_PER_UNIT_720: float = 720.0 / 1080.0
const MIN_HUD_PX: float = 14.0
const MIN_SUB_PX: float = 18.0

var _flow: MenuFlow


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func after_each() -> void:
	if _flow != null and is_instance_valid(_flow):
		_flow.call(&"_leave_heist")
		await wait_frames(3)
		_flow.queue_free()
	_flow = null
	await wait_frames(3)


static func _rect(c: Control) -> Rect2:
	var xf: Transform2D = c.get_global_transform()
	return Rect2(xf.origin, c.size * xf.get_scale())


func _find_hud() -> Hud:
	for n: Node in get_tree().root.find_children("*", "Hud", true, false):
		if n is Hud and (n as Hud).model != null:
			return n as Hud
	return null


func test_live_heist_hud_readable_at_720p() -> void:
	if UiNav.global_class(&"HeistLauncher") == null:
		skip("no HeistLauncher")
		return
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_flow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(_flow)
	await wait_frames(1)
	assert_true(_flow.direct_launch(LaunchArgs.parse(PackedStringArray(["--heist=glasshouse", "--seed=42",
			"--difficulty=0"]))), "direct launch accepted")
	var ok: bool = await wait_until(func() -> bool: return _find_hud() != null, 60.0)
	assert_true(ok, "live HUD bound to the LocalHudModel")
	if not ok:
		return
	await wait_frames(10)
	var hud: Hud = _find_hud()
	assert_true(hud != null, "HUD still live")
	if hud == null:
		return
	var vis: Rect2 = hud.get_viewport().get_visible_rect().grow(1.0)
	var small: Array[String] = []
	for n: Node in hud.find_children("*", "Label", true, false):
		var l: Label = n as Label
		if not l.is_visible_in_tree() or l.text.strip_edges() == "":
			continue
		var px: float = l.get_theme_font_size(&"font_size") * l.get_global_transform().get_scale().y * PX_PER_UNIT_720
		if px < MIN_HUD_PX:
			small.append("%s '%s' %.1fpx" % [l.get_parent().name, l.text.left(24), px])
		if not vis.encloses(_rect(l)):
			small.append("%s '%s' off-screen %s" % [l.get_parent().name, l.text.left(24), _rect(l)])
	assert_eq(small.size(), 0, "HUD text below %.0f px at 720p / off-screen: %s" % [MIN_HUD_PX, "; ".join(small)])
	var always: Array[Control] = [hud.vitals, hud.ammo, hud.teammates, hud.objectives, hud.status]
	for i: int in range(always.size()):
		for j: int in range(i + 1, always.size()):
			if always[i].is_visible_in_tree() and always[j].is_visible_in_tree():
				assert_false(_rect(always[i]).intersects(_rect(always[j])), "%s overlaps %s" % [always[i].name, always[j].name])
	var radio: ContactRadio = _flow.heist_radio
	assert_true(radio != null and radio.overlay != null, "live subtitles overlay")
	if radio != null and radio.overlay != null:
		var sub: SubtitleOverlay = radio.overlay
		assert_true(sub.font_size() * PX_PER_UNIT_720 >= MIN_SUB_PX,
				"default subtitles %.1f px at 720p (min %.0f)" % [sub.font_size() * PX_PER_UNIT_720, MIN_SUB_PX])
		var sr: Rect2 = _rect(sub)
		assert_true(vis.encloses(Rect2(sr.position.x, sr.position.y, sr.size.x, maxf(sr.size.y, 1.0))), "subtitles on screen %s" % sr)
		for w: Control in [hud.vitals, hud.ammo]:
			assert_false(sr.intersects(_rect(w)), "subtitles clear of %s (%s / %s)" % [w.name, sr, _rect(w)])


func _pad(button: JoyButton) -> void:
	UiNav.ensure_pad_ui_actions()
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(3)


## PQ-B-20: in a live heist, pad Start opens Options over the HUD (crew input paused, 720p fit) and
## pad B closes it and resumes input.
func test_live_heist_pause_with_pad() -> void:
	if UiNav.global_class(&"HeistLauncher") == null:
		skip("no HeistLauncher")
		return
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_flow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(_flow)
	await wait_frames(1)
	assert_true(_flow.direct_launch(LaunchArgs.parse(PackedStringArray(["--heist=glasshouse", "--seed=43",
			"--difficulty=0"]))))
	assert_true(await wait_until(func() -> bool: return _find_hud() != null, 60.0), "live HUD")
	await wait_frames(5)
	await _pad(JOY_BUTTON_START)
	var opts: OptionsScreen = _flow.options_menu.heist_screen
	assert_true(opts != null and opts.is_visible_in_tree(), "Start opens Options in the heist")
	if opts == null:
		return
	assert_true(CrewInput.is_held(&"options"), "local crew input paused while Options is up")
	var vis: Rect2 = opts.get_viewport().get_visible_rect().grow(1.0)
	for c: Control in opts.focus_chain:
		if c.is_visible_in_tree():
			var n: Node = c.get_parent()
			var r: Rect2 = c.get_global_rect()
			while n != null:
				if n is ScrollContainer:
					r = (n as ScrollContainer).get_global_rect()
					break
				n = n.get_parent()
			assert_true(vis.encloses(r), "%s on screen %s" % [c.name, r])
	assert_true(opts.get_viewport().gui_get_focus_owner() != null, "pad has a focused control")
	await _pad(JOY_BUTTON_B)
	await wait_frames(3)
	assert_true(_flow.options_menu.heist_screen == null or not _flow.options_menu.heist_screen.is_visible_in_tree(),
			"B closes Options")
	assert_false(CrewInput.is_held(&"options"), "input resumed")
