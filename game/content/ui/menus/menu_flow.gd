## Front-end flow controller: main menu -> heist select -> loadout -> launch -> HUD -> payday.
## Owner: ENV B. Screens only emit signals; this node swaps them (no scene changes, so the whole flow
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

var main_menu: MainMenu
var heist_select: HeistSelect
var loadout_screen: LoadoutScreen
var stub_screen: StubScreen
var payday: PaydayScreen
var current: Control
var runtime: Object = null
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
	if loadout_screen != null:
		loadout_screen.queue_free()
	loadout_screen = _add(LOADOUT_SCENE) as LoadoutScreen
	loadout_screen.back_requested.connect(show_screen.bind(heist_select))
	loadout_screen.launch_requested.connect(_on_launch_requested)
	show_screen(loadout_screen)


func _on_launch_requested(loadout: Loadout) -> void:
	launch(_heist_id, _difficulty, loadout, _time_seed())


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
## launcher the stub screen is shown and no in-heist UI is spawned.
func launch(heist_id: StringName, difficulty: int, loadout: Loadout, run_seed: int) -> void:
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
	var options: Dictionary = {"ai_teammates": ai, "loadouts": {Net.local_slot(): resolved}}
	visible = false
	_spawn_in_heist_ui()
	runtime = await launcher.call(&"launch", heist_id, run_seed, difficulty, null, options)
	if runtime == null:
		Log.error(&"ui", "HeistLauncher.launch(%s) returned null; back to the main menu" % heist_id)
		_leave_heist()
		return
	heist_launched.emit(runtime)


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
