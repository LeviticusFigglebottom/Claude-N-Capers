## Worker for ui_qa_walk.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const MAX_STEPS: int = 40

var _out: String = ""
var _heists: Array[StringName] = []
var _flow: MenuFlow = null
var _issues: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/ui_qa"
	for i: int in range(1, args.size()):
		_heists.append(StringName(args[i]))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	OnboardingTips.persist = false
	SaveService.root_dir = "user://ui_qa_profiles"
	if _heists.is_empty():
		_heists = HeistCatalog.ids()
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 40
	p.cash = 5000000
	# A memory that gives every heist a freshness: the first heist long ago (rotation), the rest repeated.
	HeistFreshness.record(p, _heists[0], true)
	for i: int in range(12):
		HeistFreshness.record(p, _heists[(i % (_heists.size() - 1)) + 1] if _heists.size() > 1 else _heists[0], true)
	SaveService.save_profile(p, SLOT)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	for heist: StringName in _heists:
		await _walk(heist)
	_flow.queue_free()
	for heist: StringName in _heists:
		await _payday(heist, p)
	SaveService.delete_profile(SLOT)
	print("QA DONE %d" % _issues)
	get_tree().quit(0)


func _walk(heist: StringName) -> void:
	_flow.show_hub()
	_flow.open_station(&"board")
	await _shot(heist, "board", _flow.board_screen)
	_flow.show_hub()
	_flow.open_station(&"planning")
	var hs: HeistSelect = _flow.heist_select
	await _frames(4)
	var i: int = HeistCatalog.ids().find(heist)
	if i >= 0 and i < hs.heist_buttons.size():
		hs.heist_buttons[0].grab_focus()
		if await _nav_to(hs.heist_buttons[i], "heist button %s" % heist):
			await _key(KEY_ENTER)
	for d: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.BRUTAL]:
		if d < hs.difficulty_buttons.size() and not hs.difficulty_buttons[d].disabled:
			if await _nav_to(hs.difficulty_buttons[d], "difficulty %d" % d):
				await _key(KEY_ENTER)
		await _shot(heist, "heist_select_d%d" % d, hs)
	if await _nav_to(hs.next_button, "Briefing button"):
		await _key(KEY_ENTER)
	await _shot(heist, "briefing", _flow.briefing_screen)
	var bs: BriefingScreen = _flow.briefing_screen
	if bs != null and bs.is_visible_in_tree():
		bs.continue_button.grab_focus()
		await _key(KEY_ENTER)
	await _shot(heist, "preplanning", _flow.preplanning_screen)
	if _flow.preplanning_screen != null and _flow.preplanning_screen.is_visible_in_tree():
		_flow.preplanning_screen.back_button.grab_focus()
		await _key(KEY_ENTER)


func _payday(heist: StringName, p: PlayerProfile) -> void:
	var r: Dictionary = HeistCatalog.sample_result()
	r["heist_id"] = heist
	var screen: PaydayScreen = (load("res://content/ui/results/payday.tscn") as PackedScene).instantiate() as PaydayScreen
	screen.apply_to_profile = false
	screen.cards_enabled = false
	get_tree().root.add_child(screen)
	screen.setup(p)
	screen.show_result(r)
	await _frames(2)
	screen.skip_count()
	await _shot(heist, "payday", screen)
	screen.queue_free()
	await _frames(2)


# --- Input ---------------------------------------------------------------------------------------

func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().process_frame


func _key(code: Key) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var u: InputEventKey = e.duplicate() as InputEventKey
	u.pressed = false
	Input.parse_input_event(u)
	await _frames(2)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _nav_to(target: Control, label: String) -> bool:
	await _frames(2)
	var keys: Array[Key] = [KEY_DOWN, KEY_RIGHT, KEY_UP, KEY_LEFT]
	var d: int = 0
	var seen: Dictionary = {}
	for _i: int in range(MAX_STEPS):
		if _focus() == target:
			return true
		seen[_focus()] = true
		await _key(keys[d])
		if seen.has(_focus()):
			d = (d + 1) % keys.size()
	print("QA ISSUE nav %s not reachable by arrows (focus on %s)" % [label, _focus()])
	_issues += 1
	return false


# --- Shots and the label scan --------------------------------------------------------------------

func _shot(heist: StringName, step: String, screen: Control) -> void:
	await _frames(12)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%s_%dx%d.png" % [_out, heist, step, img.get_width(), img.get_height()]
	img.save_png(path)
	print("QA SHOT ", path)
	if screen != null and is_instance_valid(screen) and screen.is_visible_in_tree():
		_scan("%s/%s" % [heist, step], screen)


## Flags visible labels whose text does not fit (trimmed or spilling out of their rect, or out of the viewport) and
## pairs of visible labels that overlap on screen.
func _scan(tag: String, root: Control) -> void:
	var view: Rect2 = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var labels: Array[Label] = []
	for n: Node in root.find_children("*", "Label", true, false):
		var l: Label = n as Label
		if l == null or not l.is_visible_in_tree() or l.text.strip_edges() == "" or not _on_screen(l) or _faded(l):
			continue
		labels.append(l)
		var r: Rect2 = l.get_global_rect()
		var need: float = l.get_theme_font(&"font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				l.get_theme_font_size(&"font_size")).x
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and need > r.size.x + 2.0:
			_issue(tag, "clipped '%s' needs %.0f px, has %.0f" % [l.text.left(48), need, r.size.x])
		if r.end.x > view.end.x + 1.0 or r.end.y > view.end.y + 1.0:
			_issue(tag, "off-screen '%s' %s" % [l.text.left(48), r])
	for a: int in range(labels.size()):
		for b: int in range(a + 1, labels.size()):
			var ra: Rect2 = labels[a].get_global_rect().grow(-1.0)
			var rb: Rect2 = labels[b].get_global_rect().grow(-1.0)
			if ra.intersects(rb):
				_issue(tag, "overlap '%s' x '%s'" % [labels[a].text.left(32), labels[b].text.left(32)])


## True for a label faded out on purpose (e.g. the pre-planning map hint hides itself when it does not fit).
func _faded(l: CanvasItem) -> bool:
	var n: Node = l
	while n is CanvasItem:
		if (n as CanvasItem).modulate.a < 0.05 or (n == l and l.self_modulate.a < 0.05):
			return true
		n = n.get_parent()
	return false


## False for a label scrolled out of its ScrollContainer (not a layout problem).
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
