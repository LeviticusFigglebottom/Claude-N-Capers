## Front-end flow controller (pd2_fidelity C2/C3 order): main menu -> heist select -> briefing ->
## pre-planning -> loadout (-> masks / skills / perk deck) -> launch -> HUD -> payday. Owner: ENV B.
## Back is symmetrical at every step (loadout -> pre-planning refunds the confirmed plan's cash, so a
## re-confirm never charges twice). The confirmed plan goes to HeistLauncher as options["preplan"]
## (the PreplanResult v1 from PreplanPlan.apply(); contract docs/contracts/preplanning.md, D-038).
## Screens only emit signals; this node swaps them (no scene changes, so the whole flow
## also runs inside tests). Launch uses ENV A's HeistLauncher (contracts/test_hooks.md), looked up
## dynamically; without it a stub screen offers a sample payday.
## App shell (D-024): core/boot.gd routes here. It owns launch, the HUD/payday layer, and
## HeistRuntime.teardown() + Net.leave() after results. Direct launch skips the menus:
##   godot --path game -- --heist=<id> [--seed=<n>] [--difficulty=<0..5>]   (LaunchArgs)
class_name MenuFlow
extends Control

signal heist_launched(runtime: Object)

const MAIN_SCENE: PackedScene = preload("res://content/ui/menus/main_menu.tscn")
const SELECT_SCENE: PackedScene = preload("res://content/ui/menus/heist_select.tscn")
const LOADOUT_SCENE: PackedScene = preload("res://content/ui/menus/loadout.tscn")
const STUB_SCENE: PackedScene = preload("res://content/ui/menus/stub_screen.tscn")
const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")
const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")
const RANGE_SCENE: PackedScene = preload("res://content/range/firing_range.tscn")
const BRIEFING_SCENE: PackedScene = preload("res://content/ui/briefing/briefing_screen.tscn")
const PREPLAN_SCENE: PackedScene = preload("res://content/ui/preplanning/preplanning_screen.tscn")
const MASKS_SCENE: PackedScene = preload("res://content/ui/masks/mask_screen.tscn")
const SKILLS_SCENE: PackedScene = preload("res://content/ui/progression/skill_tree_screen.tscn")
const PERKS_SCENE: PackedScene = preload("res://content/ui/progression/perk_deck_screen.tscn")

var main_menu: MainMenu
var heist_select: HeistSelect
var briefing_screen: BriefingScreen
var preplanning_screen: PreplanningScreen
var loadout_screen: LoadoutScreen
## Mask screen while open from the loadout screen (B2-03), else null.
var mask_screen: MaskScreen = null
var stub_screen: StubScreen
var payday: PaydayScreen
## Skill tree / perk deck screen while open from the loadout screen (B4-03), else null.
var progression_screen: UiScreen = null
var current: Control
var firing_range: FiringRange = null
var runtime: Object = null
## Profile slot the menu path edits (pre-planning, loadout, masks, skills share one PlayerProfile).
var profile_slot: int = 0
## The profile shared by the menu path screens (loaded when a heist is chosen).
var profile: PlayerProfile = null
## Confirmed pre-planning plan (PreplanPlan.apply()); {} = none (direct launch, or not confirmed yet).
var preplan: Dictionary = {}
var _heist_id: StringName = &""
var _difficulty: int = Enums.Difficulty.ROUTINE
var _in_heist: CanvasLayer = null
var _hud: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiBuild.theme()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.055)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	main_menu = _add(MAIN_SCENE) as MainMenu
	heist_select = _add(SELECT_SCENE) as HeistSelect
	stub_screen = _add(STUB_SCENE) as StubScreen
	main_menu.play_solo_requested.connect(show_screen.bind(heist_select))
	main_menu.firing_range_requested.connect(open_firing_range)
	main_menu.settings_requested.connect(_show_stub.bind(&"ui.menu.settings_soon", false))
	main_menu.quit_requested.connect(get_tree().quit)
	heist_select.back_requested.connect(show_screen.bind(main_menu))
	heist_select.heist_chosen.connect(_on_heist_chosen)
	stub_screen.back_requested.connect(show_screen.bind(main_menu))
	stub_screen.sample_payday_requested.connect(_show_sample_payday)
	show_screen(main_menu)
	var args: Dictionary = LaunchArgs.parse(OS.get_cmdline_user_args())
	if bool(args["direct"]) or not (args["errors"] as Array).is_empty():
		direct_launch(args)


func show_screen(screen: Control) -> void:
	for c: Node in get_children():
		if c is UiScreen:
			(c as Control).visible = c == screen
	current = screen
	if screen is MainMenu:
		(screen as MainMenu).refresh_profile()


func _add(scene: PackedScene) -> Control:
	var c: Control = scene.instantiate() as Control
	c.visible = false
	add_child(c)
	return c


func _show_stub(message_key: StringName, sample_payday: bool) -> void:
	stub_screen.setup(message_key, sample_payday)
	show_screen(stub_screen)


func _on_heist_chosen(heist_id: StringName, difficulty: int) -> void:
	_heist_id = heist_id
	_difficulty = difficulty
	preplan = {}
	profile = SaveService.load_profile(profile_slot)
	_free_screen(preplanning_screen)
	preplanning_screen = null
	_free_screen(loadout_screen)
	loadout_screen = null
	if briefing_screen == null:
		briefing_screen = BRIEFING_SCENE.instantiate() as BriefingScreen
		briefing_screen.setup(heist_id, difficulty)
		briefing_screen.visible = false
		add_child(briefing_screen)
		briefing_screen.back_requested.connect(show_screen.bind(heist_select))
		briefing_screen.continue_requested.connect(_on_briefing_continue)
	else:
		briefing_screen.setup(heist_id, difficulty)
	show_screen(briefing_screen)


## Briefing -> pre-planning (a fresh board for this heist + difficulty on the shared profile).
func _on_briefing_continue(heist_id: StringName, difficulty: int) -> void:
	_heist_id = heist_id
	_difficulty = difficulty
	preplan = {}
	_free_screen(preplanning_screen)
	preplanning_screen = PREPLAN_SCENE.instantiate() as PreplanningScreen
	preplanning_screen.profile_slot = profile_slot
	preplanning_screen.setup(heist_id, difficulty, _menu_profile())
	preplanning_screen.visible = false
	add_child(preplanning_screen)
	preplanning_screen.back_requested.connect(show_screen.bind(briefing_screen))
	preplanning_screen.confirmed.connect(_on_preplan_confirmed)
	show_screen(preplanning_screen)


## Pre-planning confirmed (cash already charged and saved by the screen) -> loadout.
func _on_preplan_confirmed(plan: Dictionary) -> void:
	preplan = plan
	_free_screen(loadout_screen)
	loadout_screen = LOADOUT_SCENE.instantiate() as LoadoutScreen
	loadout_screen.profile_slot = profile_slot
	loadout_screen.setup(_menu_profile())
	loadout_screen.visible = false
	add_child(loadout_screen)
	loadout_screen.back_requested.connect(_on_loadout_back)
	loadout_screen.launch_requested.connect(_on_launch_requested)
	loadout_screen.skills_requested.connect(open_progression.bind(SKILLS_SCENE))
	loadout_screen.perk_deck_requested.connect(open_progression.bind(PERKS_SCENE))
	loadout_screen.masks_requested.connect(open_masks)
	show_screen(loadout_screen)


## Loadout -> pre-planning: the plan is not used yet, so its local cash share is refunded (the screen
## keeps its selections; confirming again charges again).
func _on_loadout_back() -> void:
	refund_preplan()
	if preplanning_screen == null:
		show_screen(briefing_screen)
		return
	preplanning_screen.refresh()
	show_screen(preplanning_screen)


## Gives the confirmed plan's local cash share back to the profile and saves it. Returns the amount.
func refund_preplan() -> int:
	if preplan.is_empty():
		return 0
	var slot: int = preplanning_screen.local_slot if preplanning_screen != null else 0
	var amount: int = int((preplan.get("cash_spent", {}) as Dictionary).get(slot, 0))
	preplan = {}
	if amount > 0:
		var p: PlayerProfile = _menu_profile()
		p.cash += amount
		SaveService.save_profile(p, profile_slot)
	return amount


## Mask screen (B2-03) on the loadout screen's profile (committed and saved first by the loadout
## screen); Back returns to the loadout screen with its mask picker re-read from the profile.
func open_masks() -> void:
	if loadout_screen == null:
		return
	close_masks(false)
	mask_screen = MASKS_SCENE.instantiate() as MaskScreen
	mask_screen.setup(loadout_screen.profile)
	mask_screen.profile_slot = loadout_screen.profile_slot
	mask_screen.visible = false
	add_child(mask_screen)
	mask_screen.back_requested.connect(close_masks.bind(true))
	mask_screen.mask_changed.connect(_on_mask_changed)
	show_screen(mask_screen)


func close_masks(show_loadout: bool = true) -> void:
	if mask_screen != null:
		mask_screen.queue_free()
		mask_screen = null
	if show_loadout and loadout_screen != null:
		loadout_screen.refresh_masks()
		loadout_screen.refresh()
		show_screen(loadout_screen)


func _on_mask_changed(_mask_id: StringName) -> void:
	if loadout_screen != null:
		loadout_screen.refresh_masks()


func _menu_profile() -> PlayerProfile:
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	return profile


## Removes a screen from the flow right away (so it never shows up in show_screen's sweep again).
func _free_screen(screen: Control) -> void:
	if screen != null and is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()


## Skill tree / perk deck (B4-03): edits the loadout screen's profile (already saved by the loadout
## screen), saves itself, and Back returns to the refreshed loadout screen.
func open_progression(scene: PackedScene) -> void:
	if loadout_screen == null:
		return
	close_progression(false)
	var s: UiScreen = scene.instantiate() as UiScreen
	s.call(&"setup", loadout_screen.profile)
	s.set(&"profile_slot", loadout_screen.profile_slot)
	s.visible = false
	add_child(s)
	s.back_requested.connect(close_progression.bind(true))
	progression_screen = s
	show_screen(s)


func close_progression(show_loadout: bool = true) -> void:
	if progression_screen != null:
		progression_screen.queue_free()
		progression_screen = null
	if show_loadout and loadout_screen != null:
		loadout_screen.refresh()
		show_screen(loadout_screen)


## Firing range (B1-05): a 3D scene added next to the flow; the menu hides until it exits.
## Starts with the profile's resolved loadout (any weapon/mod can be swapped in-range, P7).
func open_firing_range() -> void:
	if firing_range != null:
		return
	var range_scene: FiringRange = RANGE_SCENE.instantiate() as FiringRange
	range_scene.setup(LoadoutResolver.resolve(SaveService.load_profile().loadout))
	range_scene.exit_requested.connect(close_firing_range)
	firing_range = range_scene
	visible = false
	get_parent().add_child.call_deferred(range_scene)


func close_firing_range() -> void:
	if firing_range == null:
		return
	firing_range.queue_free()
	firing_range = null
	visible = true
	show_screen(main_menu)


func _on_launch_requested(loadout: Loadout) -> void:
	launch(_heist_id, _difficulty, loadout, _time_seed(), preplan)


## Direct launch (D-024): `args` from LaunchArgs.parse(). Skips the menus and launches `heist_id`
## solo with the profile's saved loadout. Invalid input logs an error and stays on the main menu.
## Returns false when nothing was launched because of invalid input.
func direct_launch(args: Dictionary) -> bool:
	var errors: Array[String] = []
	errors.assign(args.get("errors", []) as Array)
	var heist_id: StringName = StringName(args.get("heist_id", &""))
	if errors.is_empty():
		var bad: String = LaunchArgs.validate_heist(heist_id, HeistCatalog.ids())
		if bad != "":
			errors.append(bad)
	if not errors.is_empty():
		for e: String in errors:
			Log.error(&"ui", "direct launch: %s; showing the main menu" % e)
		show_screen(main_menu)
		return false
	_heist_id = heist_id
	_difficulty = int(args.get("difficulty", Enums.Difficulty.ROUTINE))
	var run_seed: int = int(args["seed"]) if bool(args.get("has_seed", false)) else _time_seed()
	Log.info(&"ui", "direct launch: %s seed=%d difficulty=%d" % [_heist_id, run_seed, _difficulty])
	launch(_heist_id, _difficulty, SaveService.load_profile().loadout, run_seed)
	return true


## The single launch path (Launch button and direct launch): solo session, resolved loadout,
## HUD + payday layer, then HeistLauncher.launch (ENV A, looked up dynamically). Without the
## launcher the stub screen is shown and no in-heist UI is spawned. `plan` = the confirmed
## pre-planning plan ({} for direct launch); see build_launch_options().
func launch(heist_id: StringName, difficulty: int, loadout: Loadout, run_seed: int,
		plan: Dictionary = {}) -> void:
	var launcher: Script = UiNav.global_class(&"HeistLauncher")
	if launcher == null:
		_show_stub(&"ui.stub.launcher_missing", true)
		return
	_heist_id = heist_id
	_difficulty = difficulty
	var resolved: Loadout = LoadoutResolver.resolve(loadout)
	var ai: int = HeistCatalog.heist_list().solo_ai_for(heist_id)
	var profile: PlayerProfile = SaveService.load_profile()
	Net.start_solo(profile.profile_name, ai)
	var options: Dictionary = build_launch_options(ai, Net.local_slot(), resolved, plan)
	visible = false
	_spawn_in_heist_ui()
	runtime = await launcher.call(&"launch", heist_id, run_seed, difficulty, null, options)
	if runtime == null:
		Log.error(&"ui", "HeistLauncher.launch(%s) returned null; back to the main menu" % heist_id)
		_leave_heist()
		return
	# The HUD binds HeistRuntime's LocalHudModel itself through group G.LOCAL_HUD_MODEL (ui_hud.md v1.1).
	heist_launched.emit(runtime)


## HeistLauncher.launch options (contracts/test_hooks.md): `ai_teammates`, `loadouts` = {slot: resolved
## Loadout}, and `preplan` = the PreplanResult v1 (PreplanPlan.apply(), contract preplanning.md) when a
## plan was confirmed (omitted when `plan` is empty, e.g. direct launch).
static func build_launch_options(ai_teammates: int, local_slot: int, resolved: Loadout,
		plan: Dictionary = {}) -> Dictionary:
	var options: Dictionary = {"ai_teammates": ai_teammates, "loadouts": {local_slot: resolved}}
	if not plan.is_empty():
		options["preplan"] = plan
	return options


## Menu-side seed (not gameplay RNG): the run seed handed to HeistLauncher.
static func _time_seed() -> int:
	return int(Time.get_unix_time_from_system())


## True while the HUD/payday layer of a launched heist exists.
func in_heist_ui_spawned() -> bool:
	return _in_heist != null


## HUD + payday (listening for heist_ended) on their own layer above the map.
func _spawn_in_heist_ui() -> void:
	_in_heist = CanvasLayer.new()
	_in_heist.layer = 10
	add_sibling.call_deferred(_in_heist)
	_hud = HUD_SCENE.instantiate() as Control
	_in_heist.add_child(_hud)
	var pd: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	pd.listen_heist_ended = true
	pd.visible = false
	pd.continue_pressed.connect(_leave_heist)
	_in_heist.add_child(pd)
	EventBus.heist_ended.connect(_on_heist_ended, CONNECT_ONE_SHOT)


func _on_heist_ended(_result: Dictionary) -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _leave_heist() -> void:
	if runtime != null and is_instance_valid(runtime) and runtime.has_method(&"teardown"):
		runtime.call(&"teardown")
	runtime = null
	if EventBus.heist_ended.is_connected(_on_heist_ended):
		EventBus.heist_ended.disconnect(_on_heist_ended)
	if _in_heist != null:
		_in_heist.queue_free()
		_in_heist = null
		_hud = null
	Net.leave()
	visible = true
	show_screen(main_menu)


func _show_sample_payday() -> void:
	if payday == null:
		payday = PAYDAY_SCENE.instantiate() as PaydayScreen
		payday.apply_to_profile = false  # sample data must not pay out into the real profile
		payday.visible = false
		add_child(payday)
		payday.continue_pressed.connect(show_screen.bind(main_menu))
	show_screen(payday)
	payday.show_result(HeistCatalog.sample_result())
