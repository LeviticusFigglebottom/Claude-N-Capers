## Worker for crew_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]

var _out: String = ""
var _issues: int = 0
var _flow: MenuFlow = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/crew"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://crew_capture_profiles_%d" % OS.get_process_id()  # LEAD r252: not into the out dir (repo tree)
	OnboardingTips.persist = false
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = "Host"
	p.level = 25
	for id: StringName in [&"weapon.corsair_ar", &"weapon.brute_12", &"weapon.hornet_9", &"weapon.heron_308"]:
		if not p.owned_weapons.has(id):
			p.owned_weapons.append(id)
	for id: StringName in [&"mod.corsair_suppressor", &"mod.rail_prism_scope", &"mod.corsair_vertical_grip",
			&"mod.corsair_extended_mag", &"mod.rail_laser"]:
		p.owned_mods.append(id)
	CrewLoadouts.set_entry(p, 0, {"weapon": &"weapon.corsair_ar", "mods": [&"mod.corsair_suppressor", &"mod.rail_prism_scope"],
		"armor": &"armor.flak_rig", "mask": MaskLocker.available_ids(p)[0] if not MaskLocker.available_ids(p).is_empty() else &"",
		"outfit": &"dutch"})
	CrewLoadouts.set_entry(p, 2, {"weapon": &"weapon.brute_12", "armor": &"armor.heavy_vest"})
	SaveService.save_profile(p, SLOT)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await _frames(30)
	_flow.show_hub()
	await _shots("hub", _flow.hub)
	_flow.hub.crew_button.pressed.emit()
	await _frames(4)
	var cs: CrewScreen = _flow.current as CrewScreen
	if cs == null:
		_issue("crew", "the hub did not open the Bot Crew screen")
	else:
		(cs.rows["weapon"] as Control).grab_focus()
		await _shots("crew_bot1", cs)
		cs.select_bot(1)
		await _shots("crew_bot2_default", cs)
		cs.select_bot(0)
		await _frames(2)
		(cs.bot_tabs[0] as Control).grab_focus()
		for _i: int in range(cs.rows.size()):  # pad d-pad down from the tab to the last row (Outfit)
			await _button(JOY_BUTTON_DPAD_DOWN)
		var f: Control = get_viewport().gui_get_focus_owner()
		if f != cs.rows["outfit"]:
			_issue("crew_pad", "d-pad down from Bot 1 ends on %s, not Outfit" % (f.name if f != null else "nothing"))
		if not InteractionPanel.pad_active:
			_issue("crew_pad", "pad input did not switch the glyphs to the pad")
		await _shots("crew_bot1_pad", cs)
		cs.back_button.pressed.emit()
		await _frames(4)
	_flow.show_lobby()
	await _frames(4)
	var ls: LobbyScreen = _flow.lobby_screen
	ls.host_port_edit.text = "24733"
	print("CREW host -> %s" % error_string(ls.host()))
	await _frames(60)
	await _shots("lobby_bots", ls)
	_flow.lobby.leave()
	print("CREW DONE %d" % _issues)
	SaveService.delete_profile(SLOT)
	get_tree().quit(0)


func _shots(tag: String, screen: Control) -> void:
	for s: Vector2i in SIZES:
		get_window().size = s
		await _frames(12)
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = "%s/%s_%dx%d.png" % [_out, tag, img.get_width(), img.get_height()]
		img.save_png(path)
		print("CREW SHOT ", path)
		if screen != null and is_instance_valid(screen) and screen.is_visible_in_tree():
			_scan("%s@%d" % [tag, s.y], screen)
	get_window().size = SIZES[0]


func _button(b: JoyButton) -> void:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var u: InputEventJoypadButton = e.duplicate() as InputEventJoypadButton
	u.pressed = false
	Input.parse_input_event(u)
	await _frames(2)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().process_frame


## Clipped / trimmed / off-screen / overlapping visible labels (ui_qa_walk_worker's scan).
func _scan(tag: String, root: Control) -> void:
	var view: Rect2 = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var labels: Array[Label] = []
	for n: Node in root.find_children("*", "Label", true, false):
		var l: Label = n as Label
		if l == null or not l.is_visible_in_tree() or l.text.strip_edges() == "" or not _on_screen(l):
			continue
		labels.append(l)
		var r: Rect2 = l.get_global_rect()
		var need: float = l.get_theme_font(&"font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				l.get_theme_font_size(&"font_size")).x
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and need > r.size.x + 2.0 and not l.text.contains("\n"):
			_issue(tag, "clipped '%s' needs %.0f px, has %.0f" % [l.text.left(48), need, r.size.x])
		if r.end.x > view.end.x + 1.0 or r.end.y > view.end.y + 1.0:
			_issue(tag, "off-screen '%s' %s" % [l.text.left(48), r])
	for a: int in range(labels.size()):
		for b: int in range(a + 1, labels.size()):
			if labels[a].get_global_rect().grow(-1.0).intersects(labels[b].get_global_rect().grow(-1.0)):
				_issue(tag, "overlap '%s' x '%s'" % [labels[a].text.left(32), labels[b].text.left(32)])


func _on_screen(l: Control) -> bool:
	var p: Node = l.get_parent()
	while p != null:
		if p is ScrollContainer:
			return (p as Control).get_global_rect().grow(1.0).encloses(l.get_global_rect())
		p = p.get_parent()
	return true


func _issue(tag: String, what: String) -> void:
	_issues += 1
	print("QA ISSUE %s %s" % [tag, what])
