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
	BTestUtil.pin_menu_hub(true)  # C\'s 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
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


## PQ-B-20 / PO-4: in a live heist, pad Start opens the pause menu (crew input paused, Resume focused);
## d-pad + A opens Options over it (720p fit); B returns to the pause menu, B again resumes input.
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
	var pm: PauseMenu = _flow.options_menu.pause_menu
	assert_true(pm != null and pm.is_visible_in_tree(), "Start opens the pause menu")
	if pm == null:
		return
	assert_true(CrewInput.is_held(&"options"), "local crew input paused while the pause menu is up")
	await wait_frames(2)
	assert_eq(pm.get_viewport().gui_get_focus_owner(), pm.resume_button as Control, "Resume focused")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	assert_eq(pm.get_viewport().gui_get_focus_owner(), pm.options_button as Control)
	await _pad(JOY_BUTTON_A)
	var opts: OptionsScreen = _flow.options_menu.heist_screen
	assert_true(opts != null and opts.is_visible_in_tree(), "A opens Options over the pause menu")
	if opts == null:
		return
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
	assert_true(pm.is_visible_in_tree(), "back in the pause menu")
	assert_true(CrewInput.is_held(&"options"), "still paused")
	await _pad(JOY_BUTTON_B)
	await wait_frames(3)
	assert_true(_flow.options_menu.pause_menu == null, "B resumes")
	assert_false(CrewInput.is_held(&"options"), "input resumed")


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(3)


## PQ-B-21: a live heist ends (HeistRuntime.end_heist) -> payday -> card -> Continue -> main menu,
## keyboard only, everything on screen at 720p.
func test_live_heist_end_to_menus_keyboard() -> void:
	if UiNav.global_class(&"HeistLauncher") == null:
		skip("no HeistLauncher")
		return
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_flow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(_flow)
	await wait_frames(1)
	assert_true(_flow.direct_launch(LaunchArgs.parse(PackedStringArray(["--heist=glasshouse", "--seed=44",
			"--difficulty=0"]))))
	assert_true(await wait_until(func() -> bool: return _find_hud() != null and _flow.runtime != null, 60.0), "live")
	var escaped: Array[int] = [Net.local_slot()]
	_flow.runtime.call(&"end_heist", true, escaped)
	var pd: Array[PaydayScreen] = [null]
	assert_true(await wait_until(func() -> bool:
		for n: Node in get_tree().root.find_children("*", "PaydayScreen", true, false):
			if (n as PaydayScreen).is_visible_in_tree():
				pd[0] = n as PaydayScreen
				return true
		return false, 10.0), "payday shown after the heist ends")
	var s: PaydayScreen = pd[0]
	if s == null:
		return
	var vis: Rect2 = s.get_viewport().get_visible_rect().grow(1.0)
	assert_true(vis.encloses(s.continue_button.get_global_rect()), "Continue on screen")
	s.continue_button.grab_focus()
	await wait_frames(2)
	await _key(KEY_ENTER)
	if s.has_card_pick() or s.cards_stage:
		assert_true(s.cards_stage, "Enter opens the cards")
		s.tick(PaydayScreen.INPUT_GRACE_S + 0.01)
		await _key(KEY_1)
		assert_eq(s.picked_index, 0, "key 1 picks")
		await wait_frames(2)
		await _key(KEY_ENTER)
	assert_true(await wait_until(func() -> bool: return _flow.current is MainMenu and _flow.visible, 10.0),
			"Continue returns to the main menu")
	_flow.queue_free()
	_flow = null
	await wait_frames(3)


## D-082 fix (lead ruling): in a live heist, pad-only: Start -> d-pad to Leave Heist (on screen at 720p)
## -> A opens the confirm (focus on Cancel) -> B cancels -> Leave again -> d-pad to Confirm -> A leaves
## the heist and returns to the hub.
func test_live_heist_leave_with_pad() -> void:
	if UiNav.global_class(&"HeistLauncher") == null:
		skip("no HeistLauncher")
		return
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_flow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(_flow)
	await wait_frames(1)
	_flow.show_hub()
	await wait_frames(1)
	assert_true(_flow.direct_launch(LaunchArgs.parse(PackedStringArray(["--heist=glasshouse", "--seed=45",
			"--difficulty=0"]))))
	assert_true(await wait_until(func() -> bool: return _find_hud() != null and _flow.runtime != null, 60.0), "live")
	await wait_frames(5)
	await _pad(JOY_BUTTON_START)
	var pm: PauseMenu = _flow.options_menu.pause_menu
	assert_true(pm != null, "Start opens the pause menu (PO-4: Leave Heist lives there)")
	if pm == null:
		return
	var vis: Rect2 = pm.get_viewport().get_visible_rect().grow(1.0)
	assert_true(vis.encloses(pm.leave_button.get_global_rect()), "Leave Heist on screen at 720p")
	await wait_frames(2)
	for _attempt: int in range(2):
		var steps: int = 0
		while pm.get_viewport().gui_get_focus_owner() != pm.leave_button and steps < 6:
			await _pad(JOY_BUTTON_DPAD_DOWN)
			steps += 1
		assert_eq(pm.get_viewport().gui_get_focus_owner(), pm.leave_button as Control, "d-pad reaches Leave Heist")
		await _pad(JOY_BUTTON_A)
		await wait_frames(2)
		assert_true(pm.is_confirming(), "A opens the confirm")
		assert_eq(pm.get_viewport().gui_get_focus_owner(), pm.cancel_button as Control, "focus on Cancel")
		assert_true(vis.encloses(pm.confirm_button.get_global_rect()), "Confirm on screen at 720p")
		if _attempt == 0:
			await _pad(JOY_BUTTON_B)
			await wait_frames(2)
			assert_false(pm.is_confirming(), "B cancels the confirm")
			assert_true(_flow.runtime != null, "still in the heist")
			assert_true(pm.is_visible_in_tree(), "pause menu stays open")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	assert_eq(pm.get_viewport().gui_get_focus_owner(), pm.cancel_button as Control, "d-pad stays in the dialog")
	await _pad(JOY_BUTTON_DPAD_LEFT)
	assert_eq(pm.get_viewport().gui_get_focus_owner(), pm.confirm_button as Control)
	await _pad(JOY_BUTTON_A)
	# Lead failure pass: leaving solo is an abort, so the failure payday comes first; A on Continue goes home.
	var pd: PaydayScreen = _flow.get(&"_heist_payday") as PaydayScreen
	assert_true(await wait_until(func() -> bool: return pd != null and pd.visible, 10.0), "the failure payday shows")
	if pd != null:
		assert_eq((pd.value_labels[&"fail_reason"] as Label).text, UiText.t(&"ui.results.fail.abort"))
		await wait_frames(30)  # the payday's input grace
		for _i: int in range(3):
			if not is_instance_valid(pd) or not pd.visible:
				break
			await _pad(JOY_BUTTON_A)
			await wait_frames(5)
	assert_true(await wait_until(func() -> bool: return _flow.current == (_flow.hub as Control) and _flow.visible, 10.0),
			"Confirm leaves the heist to the hub")
	assert_true(_flow.runtime == null, "heist torn down")
	assert_false(CrewInput.is_held(&"options"), "input pause released")
