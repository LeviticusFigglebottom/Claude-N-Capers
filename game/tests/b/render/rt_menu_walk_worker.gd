## Worker for rt_menu_walk.gd (loaded at runtime so autoloads exist when it compiles). Real input only on the menus:
## arrow keys to move focus, Enter to press (as real_input_run_worker.gd). The run ends the heist through the runtime
## (stated shortcut: the in-heist play is P's / A's; this walk is the menus around it).
extends Node

const RT: StringName = &"rolling_thunder"
const MAX_STEPS: int = 80
const SIDE_KEYS: Dictionary = {SIDE_LEFT: KEY_LEFT, SIDE_TOP: KEY_UP, SIDE_RIGHT: KEY_RIGHT, SIDE_BOTTOM: KEY_DOWN}
## Every RT pre-planning asset (the WIP def's preplanning block) -> where it is bought: &"" = the crew tab, else a point.
const ASSETS: Array[Array] = [
	[&"asset.intel_route", &""], [&"asset.intel_cameras", &""], [&"asset.intel_guard_posts", &""],
	[&"asset.extra_cable_ties", &""], [&"asset.spare_body_bags", &""], [&"asset.lift_power", &""],
	[&"asset.signal_insider", &"pp_signals"], [&"asset.alternate_entry", &"pp_spawn_carpark"],
	[&"asset.ammo_bag_drop", &"pp_drop_site"], [&"asset.doctor_bag_drop", &"pp_drop_carpark"],
	[&"asset.body_bag_case_drop", &"pp_drop_diner_yard"], [&"asset.thermite_drop", &"pp_drop_underpass"],
	[&"asset.c4_drop", &"pp_drop_underpass"], [&"asset.sniper_position", &"pp_perch_roof"],
	[&"asset.escape_position", &"pp_escape_underpass"],
]
## Kept in the plan (the rest is bought, then taken back): success keeps the C4 drop and the signal insider.
const KEEP: Dictionary = {
	"success": [&"asset.c4_drop", &"asset.signal_insider", &"asset.intel_route"],
	"fail": [&"asset.thermite_drop", &"asset.alternate_entry", &"asset.ammo_bag_drop"],
}

var _out: String = ""
var _mode: String = "success"
var _n: int = 0
var _issues: int = 0
var _flow: MenuFlow = null
var _fx: RefCounted = preload("res://tests/b/staged_heist_fixture.gd").new()


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_mode = args[1] if args.size() > 1 else "success"
	_out = (args[0] if args.size() > 0 else OS.get_user_data_dir() + "/rt_menu_walk").path_join(_mode)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().process_frame


func _key(code: Key, hold_s: float = 0.0) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	if hold_s > 0.0:
		await get_tree().create_timer(hold_s).timeout
	else:
		await _frames(2)
	var u: InputEventKey = e.duplicate() as InputEventKey
	u.pressed = false
	Input.parse_input_event(u)
	await _frames(2)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _nav_to(target: Control, label: String) -> bool:
	await _frames(2)
	if target == null or not target.is_visible_in_tree():
		_issue("nav", "%s is not on screen" % label)
		return false
	# The shortest arrow-key path over the game's own focus graph (Control.find_valid_focus_neighbor), then those keys
	# are sent as real input; a step that lands elsewhere is re-planned. No path = the target is unreachable.
	for _i: int in range(MAX_STEPS):
		var at: Control = _focus()
		if at == target:
			return true
		if at == null:
			await _key(KEY_DOWN)  # nothing focused yet: the first key gives focus
			continue
		var side: int = _first_step(at, target)
		if side < 0:
			_issue("nav", "%s not reachable by arrow keys from %s" % [label, at.name])
			return false
		await _key(SIDE_KEYS[side])
	_issue("nav", "%s not reached in %d keys (focus on %s)" % [label, MAX_STEPS, _focus()])
	return false


## The first arrow (a Side) on a shortest focus path from `from` to `to`, or -1.
func _first_step(from: Control, to: Control) -> int:
	var first: Dictionary = {from: -1}
	var queue: Array[Control] = [from]
	while not queue.is_empty():
		var c: Control = queue.pop_front()
		for side: int in SIDE_KEYS:
			var nb: Control = c.find_valid_focus_neighbor(side as Side)
			if nb == null or first.has(nb):
				continue
			first[nb] = side if c == from else first[c]
			if nb == to:
				return int(first[nb])
			queue.append(nb)
	return -1


func _press(target: Control, label: String) -> bool:
	print("RTWALK step %s (t=%.0f s)" % [label, Time.get_ticks_msec() / 1000.0])
	if not await _nav_to(target, label):
		return false
	await _key(KEY_ENTER)
	return true


func _shot(tag: String, frames: int = 20) -> void:
	await _frames(frames)
	await RenderingServer.frame_post_draw
	_n += 1
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%02d_%s_%dx%d.png" % [_out, _n, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("RTWALK SHOT ", path)


func _issue(what: String, text: String) -> void:
	_issues += 1
	print("RTWALK ISSUE %s: %s" % [what, text])


func _done() -> void:
	SaveService.delete_profile(0)
	_fx.call(&"unstage")
	print("RTWALK DONE %d" % _issues)
	get_tree().quit(0)


func _run() -> void:
	SaveService.root_dir = "user://rt_menu_walk_%d" % OS.get_process_id()
	GameSettings.root_dir = SaveService.root_dir + "_settings"
	OnboardingTips.persist = false
	var p: PlayerProfile = PlayerProfile.new_default()
	p.cash = 500000
	SaveService.save_profile(p, 0)
	if (_fx.call(&"stage") as Array).is_empty() and not HeistCatalog.ids().has(RT):
		_issue("stage", "RT is neither offered nor stageable")
		_done()
		return
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await _frames(30)
	await _press(_flow.main_menu.safehouse_button, "Safehouse")
	await _press(_flow.hub.station_button(&"planning"), "Planning")
	var hs: HeistSelect = _flow.heist_select
	var idx: int = HeistCatalog.ids().find(RT)
	if idx < 0 or idx >= hs.heist_buttons.size():
		_issue("select", "RT has no heist button")
		_done()
		return
	await _press(hs.heist_buttons[idx], "RT heist button")
	var diff: int = Enums.Difficulty.ROUTINE if _mode == "success" else Enums.Difficulty.HAZARDOUS
	await _press(hs.difficulty_buttons[diff], "difficulty %d" % diff)
	if hs.selected_heist_id() != RT or hs.selected_difficulty != diff:
		_issue("select", "selected %s @%d, wanted RT @%d" % [hs.selected_heist_id(), hs.selected_difficulty, diff])
	await _shot("heist_select")
	await _press(hs.next_button, "Next")
	await _shot("briefing", 30)
	await _press(_flow.briefing_screen.continue_button, "briefing Continue")
	await _shot("preplanning", 30)
	await _preplan()
	await _press(_flow.preplanning_screen.confirm_button, "pre-planning Confirm")
	await _frames(20)
	if not _flow.loadout_screen.is_visible_in_tree():
		_issue("preplan", "Confirm did not reach the loadout (%s)" % _flow.preplanning_screen.reason_label.text)
		await _shot("preplan_stuck")
		_done()
		return
	await _shot("loadout")
	await _press(_flow.loadout_screen.launch_button, "Launch")
	var t0: int = Time.get_ticks_msec()
	while _flow.runtime == null and Time.get_ticks_msec() - t0 < 120000:
		await _frames(5)
	if _flow.runtime == null:
		_issue("launch", "the heist did not launch")
		_done()
		return
	await get_tree().create_timer(5.0).timeout
	await _shot("in_heist_casing", 5)
	_report_drops()
	await _payday()
	_done()


func _preplan() -> void:
	var ps: PreplanningScreen = _flow.preplanning_screen
	var keep: Array = KEEP[_mode]
	for row: Array in ASSETS:
		var id: StringName = row[0]
		var pid: StringName = row[1]
		if not await _open(ps, pid):
			continue
		var i: int = ps.asset_button_ids.find(id)
		if i < 0:
			_issue("preplan", "%s not offered at %s (offered %s)" % [id, pid if pid != &"" else &"crew", ps.asset_button_ids])
			continue
		var cash0: int = ps.cash_left()
		await _press(ps.asset_buttons[i], String(id))
		var took: bool = ps.is_selected(id)
		print("RTWALK buy %s at %s: %s (cash %d -> %d, favors %s) %s" % [id, pid if pid != &"" else &"crew",
				"OK" if took else "refused", cash0, ps.cash_left(), ps.favors_label.text, ps.reason_label.text])
		if took and not keep.has(id):
			i = ps.asset_button_ids.find(id)
			await _press(ps.asset_buttons[i], String(id) + " (take back)")
			if ps.is_selected(id):
				_issue("preplan", "%s could not be taken back" % id)
		elif not took and keep.has(id):
			_issue("preplan", "%s (kept on this run) refused: %s" % [id, ps.reason_label.text])
	await _open(ps, &"")
	await _shot("preplan_plan", 10)
	print("RTWALK plan: %s" % ps.plan_label.text.replace("\n", " / "))


## Shows the crew assets (pid &"") or point `pid` (its floor tab first, then its marker), by keys.
func _open(ps: PreplanningScreen, pid: StringName) -> bool:
	if pid == &"":
		return await _press(ps.crew_button, "crew tab")
	var fl: int = int(ps.board.blueprint.point(pid).get("floor", 0))
	if fl < ps.floor_buttons.size() and ps.blueprint_view.floor_index != fl:
		await _press(ps.floor_buttons[fl], "floor tab %d" % fl)
	if not ps.blueprint_view.markers.has(pid):
		_issue("preplan", "no marker for %s on floor %d" % [pid, fl])
		return false
	if not await _press(ps.blueprint_view.markers[pid] as Control, String(pid)):
		return false
	if ps.selected_point != pid:
		_issue("preplan", "pressed %s but %s is selected" % [pid, ps.selected_point])
		return false
	return true


func _report_drops() -> void:
	var drops: Array[String] = []
	var at_drop: bool = false
	var drop_pos: Vector2 = (_flow.preplanning_screen.board.blueprint.point(&"pp_drop_underpass").get("pos",
			Vector2.INF) as Vector2)
	for n: Node in get_tree().root.find_children("*", "ItemPickup", true, false):
		var ip: ItemPickup = n as ItemPickup
		var p: Vector3 = ip.global_position
		drops.append("%s x%d at (%.0f, %.0f)" % [ip.item_id, ip.count, p.x, p.z])
		if ip.item_id == &"item.c4" and Vector2(p.x, p.z).distance_to(drop_pos) < 3.0:
			at_drop = true
	print("RTWALK item pickups: %s" % ", ".join(drops))
	if _mode == "success":
		if at_drop:
			print("RTWALK c4 drop: the bought C4 box is at pp_drop_underpass %s" % drop_pos)
		else:
			_issue("c4", "no C4 box within 3 m of pp_drop_underpass %s" % drop_pos)


func _payday() -> void:
	var win: bool = _mode == "success"
	if win:
		_flow.runtime.call(&"end_heist", true, [Net.local_slot()] as Array[int])
	else:
		_flow.runtime.call(&"end_heist", false, [] as Array[int])
	var pd: PaydayScreen = null
	var t0: int = Time.get_ticks_msec()
	while pd == null and Time.get_ticks_msec() - t0 < 20000:
		for n: Node in get_tree().root.find_children("*", "PaydayScreen", true, false):
			if (n as PaydayScreen).is_visible_in_tree():
				pd = n as PaydayScreen
		await _frames(3)
	if pd == null:
		_issue("payday", "no payday screen")
		return
	await get_tree().create_timer(3.5).timeout
	await _shot("payday", 5)
	await _press(pd.continue_button, "payday Continue")
	if pd.cards_stage:
		await get_tree().create_timer(PaydayScreen.INPUT_GRACE_S + 0.3).timeout
		await _shot("payday_cards")
		await _press(pd.card_views[0], "card 1")
		await _press(pd.continue_button, "cards Continue")
	t0 = Time.get_ticks_msec()
	while not (_flow.current == (_flow.hub as Control) and _flow.visible) and Time.get_ticks_msec() - t0 < 15000:
		await _frames(3)
	if _flow.current != (_flow.hub as Control):
		_issue("payday", "did not return to the hub")
	await _shot("hub_after", 30)
