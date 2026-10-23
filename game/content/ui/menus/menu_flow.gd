## Front-end flow controller (pd2_fidelity C2/C3 order): main menu -> safehouse hub (C9) -> the
## Board (C1) or the planning table (heist select) -> briefing -> pre-planning -> loadout (-> masks /
## skills / perk deck) -> launch -> HUD -> payday. Owner: ENV B.
## Safehouse (B4-07): HubMenu lists the stations of data/ui/hub_stations.tres; every station opens
## through open_station(id), which is also the API for ENV C's 3D safehouse interactables. A Board
## contract carries `is_pro` to the launch options (options["is_pro"]) and to the payday screen.
## Co-op (B4-11): the crew station opens LobbyScreen; while a LobbySession is live the lobby is home
## (show_hub shows it) and the host launches with every human slot's loadout (see the section at the end).
## Back is symmetrical at every step (loadout -> pre-planning refunds the confirmed plan's cash, so a
## re-confirm never charges twice). The confirmed plan goes to HeistLauncher as options["preplan"]
## (the PreplanResult v1 from PreplanPlan.apply(); contract docs/contracts/preplanning.md, D-038).
## Screens only emit signals; this node swaps them (no scene changes, so the whole flow
## also runs inside tests). Launch uses ENV A's HeistLauncher (contracts/test_hooks.md), looked up
## dynamically; without it a stub screen offers a sample payday.
## App shell (D-024): core/boot.gd routes here. It owns launch, the HUD/payday layer, and
## HeistRuntime.teardown() + Net.leave() after results. Direct launch skips the menus:
##   godot --path game -- --heist=<id> [--seed=<n>] [--difficulty=<0..5>]   (LaunchArgs)
## Options (B5-01): GameSettings.current() is applied in _ready (audio buses, window, InputMap);
## `options_menu.open()` (MenuOptions) shows OptionsScreen from the main menu (Options) and the hub's profile
## panel; in a heist the `pause` action opens it over the HUD (the local crew's input is paused, the
## mouse released; Back closes it and restores both). There is no other pause menu.
## Music (B5-03, D-062): options["music_track"] = MusicCatalog.resolve_choice(profile) (the host's profile in
## co-op; &"" = heist default). The `jukebox` station opens JukeboxScreen (hub previews via C's MusicDirector).
## 3D hub (B6-06, QC-45..49): `safehouse` (SafehouseHost) is show_hub()'s 3D branch: ENV C's safehouse scene
## from data/ui/safehouse_hub.tres, the local walker, station signals -> open_station, the hub HUD and the
## pause menu. The 2D HubMenu stays the fallback (scene / class / walker missing, Options "menu" mode, co-op).
## Drop-in (B6-04, ENV A's HeistDropIn): the co-op host's launch copies LobbyState.dropin_policy into A's service
## (DropInFlow.apply_host_policy; A decides every request, the heist JoinRequestDialog only shows A's `ask`s). The
## lobby's "Drop in to a running heist" opens DropInJoinScreen through `drop_in` (DropInFlow: pick -> Net.join ->
## HeistDropIn.request_join); on joined the in-heist UI comes up like a co-op client launch (A's service already
## ran HeistLauncher.launch_client); a failure shows its reason, Back returns to the lobby with it.
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
const HUB_SCENE: PackedScene = preload("res://content/ui/hub/hub_menu.tscn")
const BOARD_SCENE: PackedScene = preload("res://content/ui/board/board_screen.tscn")
const LOBBY_SCENE: PackedScene = preload("res://content/ui/lobby/lobby_screen.tscn")
const ACHIEVEMENTS_SCENE: PackedScene = preload("res://content/ui/achievements/achievements_screen.tscn")
const CREW_SCENE: PackedScene = preload("res://content/ui/crew/crew_screen.tscn")
const OPTIONS_SCENE: PackedScene = preload("res://content/ui/menus/options_screen.tscn")
const NOTORIETY_SCENE: PackedScene = preload("res://content/ui/notoriety/notoriety_screen.tscn")
const JUKEBOX_SCENE: PackedScene = preload("res://content/ui/jukebox/jukebox_screen.tscn")
const CAREER_SCENE: PackedScene = preload("res://content/ui/career/career_screen.tscn")
## HubStation.target values open_station() understands.
const TARGET_BOARD: StringName = &"board"
const TARGET_HEIST_SELECT: StringName = &"heist_select"
const TARGET_LOADOUT: StringName = &"loadout"
const TARGET_MASKS: StringName = &"masks"
const TARGET_RANGE: StringName = &"firing_range"
const TARGET_LOBBY: StringName = &"lobby"
const TARGET_JUKEBOX: StringName = &"jukebox"
const TARGET_NOTORIETY: StringName = &"notoriety"
const TARGET_CAREER: StringName = &"career"
const TARGETS: Array[StringName] = [TARGET_BOARD, TARGET_HEIST_SELECT, TARGET_LOADOUT, TARGET_MASKS, TARGET_RANGE, TARGET_LOBBY,
		TARGET_JUKEBOX, TARGET_NOTORIETY, TARGET_CAREER]

var main_menu: MainMenu
## Safehouse hub (B4-07).
var hub: HubMenu
## The Board (B4-06), created the first time its station opens.
var board_screen: BoardScreen = null
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
## The chosen contract is a pro job (Board pin flagged pro). Heist select, the broker and direct
## launch are never pro. Goes to options["is_pro"] and PaydayScreen.is_pro.
var is_pro: bool = false
## C4 Last Breath (PD2 One Down) for the chosen contract: the planning table's toggle, or the lobby host's contract.
## Goes to options["last_breath"] (ENV A: one down before custody) and PaydayScreen.last_breath.
var last_breath: bool = false
## Pro jobs have no restart (QB-BRD1, D-049): BoardContracts.contract_key() -> expires_at for every
## failed pro Board contract. Shared with the Board, which locks those pins for the rest of their
## rotation (they can't be taken again, so the briefing can't relaunch them). Persisted in the profile
## (`pro_job_locks`, save v5, ProJobLocks) so a restart keeps the lock; the Board reloads them.
var consumed_contracts: Dictionary = {}
## Station list (data/ui/hub_stations.tres).
var stations: HubStationList
## Co-op lobby (B4-11), created the first time the crew station opens. While `lobby.is_active()` the
## lobby is "home": show_hub() shows it instead, so every Back of the contract path lands there.
var lobby_screen: LobbyScreen = null
var lobby: LobbySession = null
## Options screen opener (B5-01): options_menu.open() from the menus, `pause` in a heist (MenuOptions).
var options_menu: MenuOptions
## Contact radio + subtitles of the running heist (B7-03; ContactRadio.spawn, every peer), else null.
var heist_radio: ContactRadio = null
## Lead queue (b): the loading screen while HeistLauncher.launch runs (null once the heist is up; tests).
var loading_screen: LoadingScreen = null
## In-heist chat overlay over the HUD (B6-03; co-op sessions only), else null.
var heist_chat: ChatPanel = null
## Host's drop-in request dialog over the HUD (B6-04; co-op host only; binds to the DropInService group), else null.
var heist_join_dialog: JoinRequestDialog = null
## Drop-in wiring (B6-04): host policy + the joining client's flow (DropInFlow).
var drop_in: DropInFlow
## Joining client's drop-in screen while open, else null.
var drop_in_screen: DropInJoinScreen = null
## 3D safehouse hub mode (B6-06): see SafehouseHost.
var safehouse: SafehouseHost
## Full-screen backdrop behind every screen (dimmed / hidden over the 3D safehouse).
var background: ColorRect  ## a CaseBackdrop (PO-4)
var _heist_id: StringName = &""
var _difficulty: int = Enums.Difficulty.ROUTINE
var _in_heist: CanvasLayer = null
var _hud: Control = null
var _heist_payday: PaydayScreen = null
## The Board contract of the current contract path ({} = heist select, broker or direct launch).
var _board_contract: Dictionary = {}
## Where briefing Back returns (heist select or the Board).
var _briefing_back: Control = null
## Where the firing range returns (main menu or hub).
var _range_return: Control = null
## True once the safehouse was entered: "home" after a heist / stub is the hub, else the main menu.
var _in_safehouse: bool = false
## PO r305: the 2D home of a path opened from the main menu's direct entries (main_menu, or hub for All Stations);
## null = the safehouse path. While set, show_hub() returns there and never enters the 3D safehouse.
var _direct_home: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiBuild.theme()
	GameSettings.current().apply(get_viewport())
	options_menu = MenuOptions.new()
	options_menu.name = "Options"
	options_menu.flow = self
	add_child(options_menu)
	drop_in = DropInFlow.new()
	drop_in.name = "DropIn"
	add_child(drop_in)
	background = CaseBackdrop.new()
	background.name = "Background"
	background.color = UiAccent.app_bg()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	stations = HubStationList.load_default()
	main_menu = _add(MAIN_SCENE) as MainMenu
	hub = _add(HUB_SCENE) as HubMenu
	hub.profile_slot = profile_slot
	safehouse = SafehouseHost.new()
	safehouse.name = "Safehouse"
	add_child(safehouse)
	safehouse.setup(self)
	safehouse.pause_menu.back_requested.connect(show_hub)
	safehouse.pause_menu.station_requested.connect(open_station)
	safehouse.pause_menu.options_requested.connect(options_menu.open)
	safehouse.pause_menu.achievements_requested.connect(_open_achievements)
	safehouse.pause_menu.crew_requested.connect(_open_crew)
	safehouse.pause_menu.main_menu_requested.connect(_on_hub_back)
	heist_select = _add(SELECT_SCENE) as HeistSelect
	stub_screen = _add(STUB_SCENE) as StubScreen
	main_menu.safehouse_requested.connect(_enter_safehouse)
	main_menu.station_requested.connect(_open_from_main)
	main_menu.stations_requested.connect(_open_stations_from_main)
	main_menu.continue_requested.connect(_quick_play)
	hub.continue_requested.connect(_quick_play)
	hub.station_requested.connect(open_station)
	hub.achievements_requested.connect(_open_achievements)
	hub.crew_requested.connect(_open_crew)
	hub.options_requested.connect(options_menu.open)
	hub.notoriety_requested.connect(_open_notoriety)
	hub.career_requested.connect(_open_career)
	hub.back_requested.connect(_on_hub_back)
	main_menu.firing_range_requested.connect(open_firing_range)
	main_menu.settings_requested.connect(options_menu.open)
	main_menu.quit_requested.connect(get_tree().quit)
	heist_select.back_requested.connect(show_hub)
	heist_select.heist_chosen.connect(_on_heist_chosen)
	stub_screen.back_requested.connect(show_home)
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


## The safehouse hub with a freshly loaded profile (stations save the profile themselves): the 3D
## safehouse when available and picked in Options (B6-06, SafehouseHost), else the 2D HubMenu.
## In a co-op session the lobby is shown instead (B4-11).
func show_hub() -> void:
	if is_coop():
		show_lobby()
		return
	profile = SaveService.load_profile(profile_slot)
	HeistCatalog.progress_profile = profile  # D-139: the heist select freshness note reads the fresh profile
	if _direct_home != null:  # PO r305: a path from the main menu returns to its 2D home
		if _direct_home == hub:
			hub.refresh_profile(profile)
		show_screen(_direct_home)
		return
	_in_safehouse = true
	if safehouse.show_home(profile):
		return
	hub.refresh_profile(profile)
	show_screen(hub)


## Hub when the safehouse was entered this session, else the main menu.
func show_home() -> void:
	if _in_safehouse:
		show_hub()
	else:
		show_screen(main_menu)


## Main menu "Safehouse": the hub (3D when available), leaving any direct path.
func _enter_safehouse() -> void:
	_direct_home = null
	show_hub()


## PO r305: main menu entry for station `station_id` (the Board, Planning Table, Armory): the station's 2D screen with
## no safehouse walk; Back (every station's show_hub) returns to the main menu. Returns open_station's result.
func _open_from_main(station_id: StringName) -> bool:
	_direct_home = main_menu
	_in_safehouse = false
	safehouse.leave()
	return open_station(station_id)


## PO r305: main menu "All Stations": the 2D HubMenu (every station, the profile panel); its stations come back to
## it and its Back to the main menu.
func _open_stations_from_main() -> void:
	_direct_home = hub
	_in_safehouse = false
	safehouse.leave()
	show_hub()


func _on_hub_back() -> void:
	_direct_home = null
	_in_safehouse = false
	safehouse.leave()
	show_screen(main_menu)


## Opens safehouse station `station_id` (data/ui/hub_stations.tres; ids board, planning, armory,
## masks, range, crew, jukebox, notoriety, profile). The API for the 2D hub cards AND ENV C's 3D safehouse interactables. Leaving a
## contract path this way drops it (a confirmed plan's cash is refunded). Back on every station
## returns to the hub. Returns false (and logs an error) for an unknown id or target.
func open_station(station_id: StringName) -> bool:
	var st: HubStation = stations.find(station_id) if stations != null else null
	if st == null or not TARGETS.has(st.target):
		Log.error(&"ui", "open_station: unknown station '%s'" % station_id)
		return false
	_in_safehouse = _direct_home == null
	refund_preplan()
	safehouse.station_opened(station_id)  # ducks the 3D cabinet under every screen but the jukebox
	match st.target:
		TARGET_BOARD:
			_open_board()
		TARGET_HEIST_SELECT:
			_menu_profile()
			heist_select.refresh_preview()  # D-139: freshness changes after every payday
			show_screen(heist_select)
		TARGET_LOADOUT:
			_open_armory()
		TARGET_MASKS:
			_open_mask_screen(_menu_profile(), profile_slot, false)
		TARGET_RANGE:
			open_firing_range()
		TARGET_LOBBY:
			show_lobby()
		TARGET_JUKEBOX:
			_open_jukebox()
		TARGET_NOTORIETY:
			_open_notoriety()
		TARGET_CAREER:
			_open_career()
	return true


func _open_board() -> void:
	if board_screen == null:
		board_screen = BOARD_SCENE.instantiate() as BoardScreen
		board_screen.profile_slot = profile_slot
		board_screen.consumed = consumed_contracts
		_sync_pro_locks()
		board_screen.setup(_menu_profile())
		board_screen.visible = false
		add_child(board_screen)
		board_screen.back_requested.connect(show_hub)
		board_screen.contract_chosen.connect(_on_contract_chosen)
	else:
		_sync_pro_locks()
		board_screen.setup(_menu_profile())
	show_screen(board_screen)


## Achievements screen (B4-20) from the hub's profile panel; Back frees it and returns to the hub.
func _open_achievements() -> void:
	var screen: AchievementsScreen = ACHIEVEMENTS_SCENE.instantiate() as AchievementsScreen
	screen.setup(SaveService.load_profile(profile_slot))
	screen.visible = false
	add_child(screen)
	screen.back_requested.connect(func() -> void:
		_free_screen(screen)
		show_hub())
	show_screen(screen)


## PO-19 Bot Crew screen from the hub's profile panel / the safehouse pause menu; it saves every change itself.
## Back frees it and returns to the hub.
func _open_crew() -> void:
	var screen: CrewScreen = CREW_SCENE.instantiate() as CrewScreen
	screen.setup(_menu_profile(), profile_slot)
	screen.visible = false
	add_child(screen)
	screen.back_requested.connect(func() -> void:
		_free_screen(screen)
		show_hub())
	show_screen(screen)


## Notoriety screen (B5-02) from the hub's profile panel; it saves the profile itself on a rank-up or
## a reward choice. Back frees it and returns to the hub (show_hub re-reads the saved profile).
func _open_notoriety() -> void:
	var screen: NotorietyScreen = NOTORIETY_SCENE.instantiate() as NotorietyScreen
	screen.profile_slot = profile_slot
	screen.setup(SaveService.load_profile(profile_slot))
	screen.visible = false
	add_child(screen)
	screen.back_requested.connect(func() -> void:
		_free_screen(screen)
		show_hub())
	show_screen(screen)


## Career screen (B7-01) from the hub's profile panel or the `profile` station (hub_map v1.1; read-only).
## Back frees it and returns to the hub.
func _open_career() -> void:
	var screen: CareerScreen = CAREER_SCENE.instantiate() as CareerScreen
	screen.profile_slot = profile_slot
	screen.setup(SaveService.load_profile(profile_slot))
	screen.visible = false
	add_child(screen)
	screen.back_requested.connect(func() -> void:
		_free_screen(screen)
		show_hub())
	show_screen(screen)


## Jukebox station (B5-03): track list with hub previews; leaving it stops the preview (the screen does).
## In the 3D safehouse it previews through the cabinet (QC-48); show_hub then replays the saved pick there.
func _open_jukebox() -> void:
	var screen: JukeboxScreen = JUKEBOX_SCENE.instantiate() as JukeboxScreen
	screen.preview_target = safehouse.jukebox()
	screen.setup(SaveService.load_profile(profile_slot))
	screen.visible = false
	add_child(screen)
	screen.back_requested.connect(func() -> void:
		_free_screen(screen)
		show_hub())
	show_screen(screen)


## Live persisted pro-job locks of the menu profile -> consumed_contracts (expired ones skipped).
func _sync_pro_locks() -> void:
	var p: PlayerProfile = _menu_profile()
	ProJobLocks.prune(p, Time.get_unix_time_from_system())
	for key: Variant in p.pro_job_locks:
		consumed_contracts[key] = p.pro_job_locks[key]


## Armory station: the loadout screen without Launch (hub_mode); Masks / Skills / Perk Deck work
## as on the heist path. Back saves and returns to the hub.
func _open_armory() -> void:
	close_masks(false)
	close_progression(false)
	_free_screen(loadout_screen)
	loadout_screen = LOADOUT_SCENE.instantiate() as LoadoutScreen
	loadout_screen.hub_mode = true
	loadout_screen.profile_slot = profile_slot
	loadout_screen.setup(_menu_profile())
	loadout_screen.visible = false
	add_child(loadout_screen)
	loadout_screen.back_requested.connect(show_hub)
	_connect_loadout_subscreens(loadout_screen)
	show_screen(loadout_screen)


func _connect_loadout_subscreens(ls: LoadoutScreen) -> void:
	ls.skills_requested.connect(open_progression.bind(SKILLS_SCENE))
	ls.perk_deck_requested.connect(open_progression.bind(PERKS_SCENE))
	ls.masks_requested.connect(open_masks)


## Board contract taken (or bought from the broker) -> briefing; Back from the briefing returns to the Board.
func _on_contract_chosen(heist_id: StringName, difficulty: int, pro: bool) -> void:
	last_breath = false  # Board contracts carry no Last Breath (the planning table and the lobby do)
	_start_contract(heist_id, difficulty, pro, board_screen)
	_board_contract = board_screen.selected_contract() if pro else {}


func _add(scene: PackedScene) -> Control:
	var c: Control = scene.instantiate() as Control
	c.visible = false
	add_child(c)
	return c


func _show_stub(message_key: StringName, sample_payday: bool) -> void:
	stub_screen.setup(message_key, sample_payday)
	show_screen(stub_screen)


## Planning table (heist select) -> briefing; never a pro job.
func _on_heist_chosen(heist_id: StringName, difficulty: int) -> void:
	last_breath = heist_select.last_breath
	_start_contract(heist_id, difficulty, false, heist_select)


## A fresh contract path: drops any older pre-planning / loadout screens and shows the briefing.
func _start_contract(heist_id: StringName, difficulty: int, pro: bool, back_to: Control) -> void:
	if is_coop() and lobby.state.is_host:
		lobby.set_contract(heist_id, difficulty, pro, last_breath)  # B4-11: the lobby runs the host's contract
	is_pro = pro
	_board_contract = {}
	_briefing_back = back_to
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
		briefing_screen.back_requested.connect(_on_briefing_back)
		briefing_screen.continue_requested.connect(_on_briefing_continue)
	else:
		briefing_screen.setup(heist_id, difficulty)
	show_screen(briefing_screen)


func _on_briefing_back() -> void:
	if _briefing_back != null and _briefing_back == board_screen:
		board_screen.setup(_menu_profile())
	show_screen(_briefing_back if _briefing_back != null else heist_select)


## Briefing -> pre-planning (a fresh board for this heist + difficulty on the shared profile).
func _on_briefing_continue(heist_id: StringName, difficulty: int) -> void:
	_heist_id = heist_id
	_difficulty = difficulty
	preplan = {}
	_free_screen(preplanning_screen)
	preplanning_screen = PREPLAN_SCENE.instantiate() as PreplanningScreen
	preplanning_screen.profile_slot = profile_slot
	preplanning_screen.music_enabled = not is_coop() or lobby.state.is_host
	preplanning_screen.setup(heist_id, difficulty, _menu_profile())
	preplanning_screen.visible = false
	add_child(preplanning_screen)
	if is_coop():
		replay_lobby_votes(preplanning_screen)
	preplanning_screen.back_requested.connect(show_screen.bind(briefing_screen))
	preplanning_screen.confirmed.connect(_on_preplan_confirmed)
	show_screen(preplanning_screen)


## Pre-planning confirmed (cash already charged and saved by the screen) -> loadout.
func _on_preplan_confirmed(plan: Dictionary) -> void:
	preplan = plan
	_free_screen(loadout_screen)
	loadout_screen = LOADOUT_SCENE.instantiate() as LoadoutScreen
	loadout_screen.profile_slot = profile_slot
	var def: HeistDef = HeistRegistry.get_def(_heist_id)
	loadout_screen.start_mode = def.start_mode if def != null else &"casing"  # D-065 civilian notice
	loadout_screen.setup(_menu_profile())
	loadout_screen.visible = false
	add_child(loadout_screen)
	loadout_screen.back_requested.connect(_on_loadout_back)
	loadout_screen.launch_requested.connect(_on_launch_requested)
	_connect_loadout_subscreens(loadout_screen)
	if is_coop():
		loadout_screen.launch_button.text = UiText.t(&"ui.lobby.ready_up")
		loadout_screen.set_taken_heisters(lobby.state.heisters_taken_by_others(lobby.state.local_slot))  # D-073
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
		Career.add_spent(p, -amount)
		SaveService.save_profile(p, profile_slot)
	return amount


## Mask screen (B2-03) on the loadout screen's profile (committed and saved first by the loadout
## screen); Back returns to the loadout screen with its mask picker re-read from the profile.
func open_masks() -> void:
	if loadout_screen == null:
		return
	_open_mask_screen(loadout_screen.profile, loadout_screen.profile_slot, true)


## Mask screen on `p`; Back returns to the loadout screen (`from_loadout`) or to the hub (mask bench).
func _open_mask_screen(p: PlayerProfile, slot: int, from_loadout: bool) -> void:
	close_masks(false)
	mask_screen = MASKS_SCENE.instantiate() as MaskScreen
	mask_screen.setup(p)
	mask_screen.profile_slot = slot
	mask_screen.visible = false
	add_child(mask_screen)
	if from_loadout:
		mask_screen.back_requested.connect(close_masks.bind(true))
	else:
		mask_screen.back_requested.connect(_close_hub_masks)
	mask_screen.mask_changed.connect(_on_mask_changed)
	show_screen(mask_screen)


func _close_hub_masks() -> void:
	close_masks(false)
	show_hub()


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
	HeistCatalog.progress_profile = profile  # D-117 §2: Lethal / Cataclysm unlock from career wins
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
	_range_return = current
	if safehouse.is_active():  # B6-06: the range frees the safehouse; coming back re-enters at ReturnRange
		_range_return = hub
		safehouse.leave(safehouse.tweak.range_marker)
	var range_scene: FiringRange = RANGE_SCENE.instantiate() as FiringRange
	var range_profile: PlayerProfile = SaveService.load_profile(profile_slot)
	var range_loadout: Loadout = LoadoutResolver.resolve(range_profile.loadout)
	WeaponFinishes.stamp(range_loadout, range_profile)  # B7-04: the range viewmodel wears the finish
	range_scene.setup(range_loadout)
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
	if _range_return == hub:
		show_hub()
	else:
		show_screen(_range_return if _range_return != null else main_menu)


func _on_launch_requested(loadout: Loadout) -> void:
	if is_coop():
		_coop_ready_up(loadout)
		return
	launch(_heist_id, _difficulty, loadout, _time_seed(), preplan, is_pro)


## The HeistLauncher options the Launch button would use right now for `loadout` (local slot,
## confirmed plan, is_pro of the chosen contract). Pure apart from reading Net.local_slot().
func launch_options_for(loadout: Loadout) -> Dictionary:
	var ai: int = HeistCatalog.heist_list().solo_ai_for(_heist_id)
	var resolved: Loadout = LoadoutResolver.resolve(loadout)
	WeaponFinishes.stamp(resolved, _menu_profile())  # B7-04: Loadout.weapon_finishes
	return build_launch_options(ai, Net.local_slot(), resolved, preplan, is_pro,
			MusicCatalog.resolve_choice(_menu_profile()), _menu_profile(), last_breath)


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
	is_pro = false
	last_breath = false
	_board_contract = {}
	_difficulty = int(args.get("difficulty", Enums.Difficulty.ROUTINE))
	var run_seed: int = int(args["seed"]) if bool(args.get("has_seed", false)) else _time_seed()
	Log.info(&"ui", "direct launch: %s seed=%d difficulty=%d" % [_heist_id, run_seed, _difficulty])
	launch(_heist_id, _difficulty, SaveService.load_profile().loadout, run_seed)
	return true


## The single launch path (Launch button and direct launch): solo session, resolved loadout,
## HUD + payday layer, then HeistLauncher.launch (ENV A, looked up dynamically). Without the
## launcher the stub screen is shown and no in-heist UI is spawned. `plan` = the confirmed
## pre-planning plan ({} for direct launch); `pro` = a pro job contract; see build_launch_options().
func launch(heist_id: StringName, difficulty: int, loadout: Loadout, run_seed: int,
		plan: Dictionary = {}, pro: bool = false) -> void:
	var launcher: Script = UiNav.global_class(&"HeistLauncher")
	if launcher == null:
		_show_stub(&"ui.stub.launcher_missing", true)
		return
	_heist_id = heist_id
	_difficulty = difficulty
	is_pro = pro
	if not pro and _board_contract.is_empty():
		QuickPlay.remember(profile_slot, heist_id, difficulty)  # lead: Continue relaunches this job
	var resolved: Loadout = LoadoutResolver.resolve(loadout)
	var ai: int = HeistCatalog.heist_list().solo_ai_for(heist_id)
	var profile: PlayerProfile = SaveService.load_profile()
	WeaponFinishes.stamp(resolved, _menu_profile())  # B7-04: Loadout.weapon_finishes (teammates / A's WeaponVisuals)
	Net.start_solo(profile.profile_name, ai)
	CrewLoadouts.source = profile  # PO-19: A's runtime reads the bots' loadouts through CrewLoadouts.for_slot
	var options: Dictionary = build_launch_options(ai, Net.local_slot(), resolved, plan, pro,
			MusicCatalog.resolve_choice(profile), profile, last_breath)
	visible = false
	_spawn_in_heist_ui()
	_hand_heisters(options)
	var loading: CanvasLayer = _show_loading(heist_id, difficulty)
	runtime = await launcher.call(&"launch", heist_id, run_seed, difficulty, null, options)
	if is_instance_valid(loading):
		loading.queue_free()
	loading_screen = null
	if runtime == null:
		Log.error(&"ui", "HeistLauncher.launch(%s) returned null; back to the main menu" % heist_id)
		_leave_heist()
		return
	# The HUD binds HeistRuntime's LocalHudModel itself through group G.LOCAL_HUD_MODEL (ui_hud.md v1.1).
	heist_launched.emit(runtime)


## Lead queue (b): the loading screen (heist name + a tip) over everything while the launcher works.
func _show_loading(heist_id: StringName, difficulty: int) -> CanvasLayer:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	var screen: LoadingScreen = LoadingScreen.new()
	screen.setup(heist_id, difficulty)
	layer.add_child(screen)
	get_tree().root.add_child(layer)
	loading_screen = screen
	return layer


## HeistLauncher.launch options (contracts/test_hooks.md): `ai_teammates`, `loadouts` = {slot: resolved
## Loadout}, `preplan` = the PreplanResult v1 (PreplanPlan.apply(), contract preplanning.md) when a
## plan was confirmed (omitted when `plan` is empty, e.g. direct launch), and `is_pro` = true for a
## pro job Board contract (omitted otherwise; informational for ENV A, the payout side is ours).
## `music_track` (always present, B5-03 / D-062) = the picked track id, &"" = HeistDef.music_track; callers
## pass MusicCatalog.resolve_choice(profile) so a removed or locked pick is already &"".
## D-073: `resolved.heister` is set to the player's pick (no preference = the first heister in roster order)
## and the AI teammates get the remaining heisters as loadouts of their own (Heisters.solo / ai_loadouts:
## ENV A's default AI loadout + `heister`), so every launched slot has a distinct heister.
## PO-19: `crew` = the player's profile: the bots carry its crew loadouts (CrewLoadouts; outfit picks first, then
## each AI slot's primary / armor / mask); null keeps A's default bots.
static func build_launch_options(ai_teammates: int, local_slot: int, resolved: Loadout,
		plan: Dictionary = {}, pro: bool = false, music: StringName = &"", crew: PlayerProfile = null,
		last_breath_on: bool = false) -> Dictionary:
	var loadouts: Dictionary = {local_slot: resolved}
	if resolved != null:
		var ai_slots: Array[int] = Heisters.solo_ai_slots(local_slot, ai_teammates)
		var heisters: Dictionary = Heisters.solo(resolved.heister, local_slot, ai_teammates,
				CrewLoadouts.outfit_picks(crew, ai_slots))
		resolved.heister = StringName(heisters[local_slot])
		heisters.erase(local_slot)
		loadouts.merge(Heisters.ai_loadouts(heisters, crew))
	var options: Dictionary = {"ai_teammates": ai_teammates, "loadouts": loadouts, "music_track": music}
	if not plan.is_empty():
		options["preplan"] = plan
	if pro:
		options["is_pro"] = true
	if last_breath_on:
		options["last_breath"] = true  # C4 One Down (ENV A: one down before custody)
	return options


## Menu-side seed (not gameplay RNG): the run seed handed to HeistLauncher.
static func _time_seed() -> int:
	return int(Time.get_unix_time_from_system())


## PO-4: the HUD names teammates by their heister (slot -> heister id from the launch loadouts).
func _hand_heisters(options: Dictionary) -> void:
	if not _hud is Hud:
		return
	var map: Dictionary = {}
	var loadouts: Dictionary = options.get("loadouts", {}) as Dictionary
	for slot: Variant in loadouts:
		var l: Loadout = loadouts[slot] as Loadout
		if l != null and l.heister != &"":
			map[int(slot)] = l.heister
	_set_heister_map(map)


## The HUD crew rows / toasts and the payday name heisters from `map` (slot -> heister id).
func _set_heister_map(map: Dictionary) -> void:
	if not _hud is Hud:
		return
	(_hud as Hud).set_crew_heisters(map)
	if _heist_payday != null and is_instance_valid(_heist_payday):
		_heist_payday.crew_heisters = map


## True while the HUD/payday layer of a launched heist exists.
func in_heist_ui_spawned() -> bool:
	return _in_heist != null


## HUD + payday (listening for heist_ended) on their own layer above the map.
func _spawn_in_heist_ui() -> void:
	safehouse.leave(safehouse.tweak.heist_marker)  # B6-06: home after payday re-enters at ReturnHeist
	_in_heist = CanvasLayer.new()
	_in_heist.layer = 10
	add_sibling.call_deferred(_in_heist)
	_hud = HUD_SCENE.instantiate() as Control
	if _hud is Hud:
		(_hud as Hud).heist_id = _heist_id
		(_hud as Hud).difficulty = _difficulty  # L1.7 assault-banner skulls
		(_hud as Hud).last_breath = last_breath
	_in_heist.add_child(_hud)
	heist_radio = ContactRadio.spawn(_in_heist, _heist_id)
	var pd: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	pd.listen_heist_ended = true
	pd.start_fact_log()  # D-115: before the launch, so the mission's first objective facts are seen
	pd.is_pro = is_pro
	pd.last_breath = last_breath
	pd.profile_slot = profile_slot
	pd.visible = false
	pd.continue_pressed.connect(_on_heist_payday_continue)
	pd.retry_requested.connect(_retry_at_routine)
	_in_heist.add_child(pd)
	_heist_payday = pd
	options_menu.heist_layer = _in_heist
	options_menu.heist_payday = pd
	if is_coop():
		heist_chat = ChatPanel.new()
		heist_chat.name = "HeistChat"
		heist_chat.setup(lobby, ChatPanel.Mode.OVERLAY)
		_in_heist.add_child(heist_chat)
	if is_coop() and lobby.state.is_host:
		heist_join_dialog = JoinRequestDialog.new()
		heist_join_dialog.name = "JoinRequests"
		heist_join_dialog.pause_gameplay = true
		heist_join_dialog.auto_find = true
		heist_join_dialog.local_slot = Net.local_slot()
		# No gate: A's HeistDropIn already applied the kick list, validation and the policy (copied from the lobby
		# at launch) and asks only for `ask`; a B gate on top would decide twice (B6-04, DropInFlow).
		_in_heist.add_child(heist_join_dialog)
		heist_join_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 96)
	EventBus.heist_ended.connect(_on_heist_ended, CONNECT_ONE_SHOT)


func _on_heist_ended(result: Dictionary) -> void:
	if is_pro and not bool(result.get("success", false)):
		consume_pro_contract()
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = false
	options_menu.close_pause()  # the payday screen holds the cursor itself (MouseCapture &"payday")


## A failed pro job: its Board contract is gone for the rest of its rotation (QB-BRD1, no restart).
func consume_pro_contract() -> void:
	if not _board_contract.is_empty():
		consumed_contracts[BoardContracts.contract_key(_board_contract)] = float(_board_contract.get("expires_at", 0.0))
		var disk: PlayerProfile = SaveService.load_profile(profile_slot)  # fresh: never clobber the payday
		ProJobLocks.prune(disk, Time.get_unix_time_from_system())
		ProJobLocks.lock(disk, _board_contract)
		SaveService.save_profile(disk, profile_slot)
		ProJobLocks.lock(profile, _board_contract)
		Log.info(&"ui", "pro job failed: contract %s consumed" % BoardContracts.contract_key(_board_contract))
	_board_contract = {}


## First-heist safety net: back out of the failed heist and relaunch it at Routine, current loadout.
func _retry_at_routine() -> void:
	var heist: StringName = _heist_id
	_leave_heist()
	is_pro = false
	last_breath = false
	_board_contract = {}
	launch(heist, Enums.Difficulty.ROUTINE, SaveService.load_profile(profile_slot).loadout, _time_seed())


## Lead: Continue / Quick Play (main menu, hub) relaunches the last regular job with the current loadout.
func _quick_play() -> void:
	var p: PlayerProfile = SaveService.load_profile(profile_slot)
	var job: Dictionary = QuickPlay.last(p)
	if job.is_empty():
		return
	is_pro = false
	last_breath = false
	_board_contract = {}
	launch(StringName(job["heist_id"]), int(job["difficulty"]), p.loadout, _time_seed())


## Lead failure pass: Leave Heist from the pause menu. Solo (the only human, with authority) ends the run
## as a failure (HeistResult.fail_reason &"abort"), so the payday shows what was lost and Continue goes
## home; a client, or a host with other humans, just leaves (it must not end the heist for everyone).
func _request_leave_heist() -> void:
	options_menu.close_pause()
	var rt: Object = runtime
	var running: bool = rt != null and is_instance_valid(rt) and int(rt.get(&"phase")) != Enums.HeistPhase.ENDED
	if running and Net.is_authority() and Net.human_slots().size() <= 1 and rt.has_method(&"end_heist"):
		rt.call(&"end_heist", false, [] as Array[int], &"abort")
		return
	_leave_heist()


## C11 (lead ruling, PD2): a co-op payday's Continue takes every peer back to the crew lobby with the session
## kept (ready flags cleared for the next job); only Leave (pause menu / lobby) ends the session.
func _on_heist_payday_continue() -> void:
	if is_coop():
		_leave_heist(true)
	else:
		_leave_heist()


func _leave_heist(keep_session: bool = false) -> void:
	if Net.host_lost.is_connected(_on_client_host_lost):
		Net.host_lost.disconnect(_on_client_host_lost)  # our own Net.leave() below is not the host leaving
	if _heist_payday != null and is_instance_valid(_heist_payday):
		_heist_payday.finish_card_pick()  # QB-PC1: leaving with an unpicked card auto-picks it
	_heist_payday = null
	if runtime != null and is_instance_valid(runtime) and runtime.has_method(&"teardown"):
		runtime.call(&"teardown")
	runtime = null
	if EventBus.heist_ended.is_connected(_on_heist_ended):
		EventBus.heist_ended.disconnect(_on_heist_ended)
	options_menu.close_pause()
	if heist_chat != null and is_instance_valid(heist_chat):
		heist_chat.close()
	heist_chat = null
	heist_radio = null
	heist_join_dialog = null
	options_menu.heist_layer = null
	options_menu.heist_payday = null
	if _in_heist != null:
		_in_heist.queue_free()
		_in_heist = null
		_hud = null
	visible = true
	if keep_session and is_coop():
		lobby.state.end_round()  # C11: the next Start is a new heist (the old launch order is spent)
		lobby.set_ready(false)
		show_lobby()
		return
	Net.leave()
	show_home()


func _show_sample_payday() -> void:
	if payday == null:
		payday = PAYDAY_SCENE.instantiate() as PaydayScreen
		payday.apply_to_profile = false  # sample data must not pay out into the real profile
		payday.visible = false
		add_child(payday)
		payday.continue_pressed.connect(show_home)
	show_screen(payday)
	payday.show_result(HeistCatalog.sample_result())


# --- Co-op lobby (B4-11) ------------------------------------------------------------------------
# Flow: crew station -> LobbyScreen (host / join) -> host picks the contract on the Board or the
# planning table (sent as LobbyState.MSG_CONTRACT) -> briefing -> pre-planning (votes live over the
# lobby; a screen opened later replays LobbyState.vote_log) -> loadout, whose Launch reads "Ready Up"
# (saves, re-sends the profile summary, sets ready, back to the lobby) -> the host's Start sends
# MSG_START -> every peer gets LobbySession.started: the host launches with every human slot's
# validated loadout (launch_coop); a client needs ENV A's client-side launch (not available yet).


## True while a co-op session (hosting or joined) is live.
func is_coop() -> bool:
	return lobby != null and lobby.is_active()


## The co-op lobby screen (connect mode without a session). Re-advertises the profile's saved loadout.
func show_lobby() -> void:
	_in_safehouse = true
	if lobby == null:
		lobby = LobbySession.new()  # tests may set `lobby` first (a session on their own Net instance)
		lobby.name = "LobbySession"
	if lobby.get_parent() == null:
		add_child(lobby)
	if not lobby.started.is_connected(_on_lobby_started):
		lobby.started.connect(_on_lobby_started)
		lobby.contract_changed.connect(_on_lobby_contract_changed)
		lobby.session_left.connect(_on_lobby_left)
	if lobby_screen == null:
		lobby_screen = LOBBY_SCENE.instantiate() as LobbyScreen
		lobby_screen.profile_slot = profile_slot
		lobby_screen.setup(lobby, _menu_profile())
		lobby_screen.visible = false
		add_child(lobby_screen)
		lobby_screen.back_requested.connect(_on_lobby_back)
		lobby_screen.contract_requested.connect(_on_lobby_contract_requested)
		lobby_screen.briefing_requested.connect(_on_lobby_briefing)
		lobby_screen.loadout_requested.connect(_open_armory)  # not open_station: that refunds the plan
		lobby_screen.dropin_requested.connect(_open_drop_in)
	drop_in.lobby = lobby
	# End-of-heist sweep: back from a payday (C11) the cached profile predates the payout and level-up the payday
	# saved; reload it like show_hub does, so the crew card advertises the new level and loadout.
	profile = SaveService.load_profile(profile_slot)
	lobby.profile = _menu_profile()
	lobby_screen.profile = lobby.profile
	if is_coop():
		lobby.send_profile(lobby.profile.loadout)
	lobby_screen.refresh()
	show_screen(lobby_screen)


## Back on the lobby: leave the session (stay on the connect view), or from the connect view the hub.
func _on_lobby_back() -> void:
	if is_coop():
		lobby.leave()
		show_lobby()
		return
	show_hub()


func _on_lobby_contract_requested(target: StringName) -> void:
	if target == TARGET_BOARD:
		_open_board()
	else:
		_menu_profile()
		heist_select.refresh_preview()
		show_screen(heist_select)


## Briefing -> pre-planning -> loadout for the lobby's contract (Back on the briefing returns here).
func _on_lobby_briefing() -> void:
	var c: Dictionary = lobby.state.contract
	if c.is_empty():
		return
	refund_preplan()
	last_breath = bool(c.get("last_breath", false))
	_start_contract(c["heist"], int(c["difficulty"]), bool(c["is_pro"]), lobby_screen)


## A client whose host picked another contract leaves the old contract path (plan cash refunded).
func _on_lobby_contract_changed(_contract: Dictionary) -> void:
	if lobby.state.is_host:
		return
	if current != null and current in [briefing_screen, preplanning_screen, loadout_screen]:
		refund_preplan()
		show_lobby()


func _on_lobby_left() -> void:
	if in_heist_ui_spawned():
		return
	refund_preplan()
	if current != null and current in [briefing_screen, preplanning_screen, loadout_screen, lobby_screen]:
		show_lobby()


## Loadout "Ready Up" in co-op: the loadout screen saved the profile; advertise it and mark ready.
func _coop_ready_up(_loadout: Loadout) -> void:
	show_lobby()
	lobby.set_ready(true)


## Applies the lobby's plan votes so far to a freshly built pre-planning screen (order preserved).
func replay_lobby_votes(screen: PreplanningScreen) -> void:
	if lobby == null or screen.plan == null:
		return
	for e: Dictionary in lobby.state.vote_log:
		screen.plan.receive_vote(int(e["slot"]), StringName(e["kind"]), e["data"] as Dictionary)
	screen.refresh()


## MSG_START accepted on this peer: the host launches; a client follows when ENV A provides a
## client-side launch (`HeistLauncher.launch_client`, asked in QB-L2), else a stub explains it.
func _on_lobby_started(info: Dictionary) -> void:
	if lobby.state.is_host:
		launch_coop(info)
		return
	var launcher: Script = UiNav.global_class(&"HeistLauncher")
	if launcher != null and _script_has_method(launcher, &"launch_client"):
		_begin_client_heist(info)
		runtime = await launcher.call(&"launch_client")  # (parent = null, options = {}, timeout_s = 0): net.md A3-07
		if runtime == null:
			_leave_heist()
		else:
			_watch_host_closed()
			heist_launched.emit(runtime)
		return
	_show_stub(&"ui.lobby.client_launch_missing", false)


## A co-op client enters a heist (lobby start or drop-in): `info` {"heist", "difficulty", "is_pro"}; the menus
## hide and the in-heist UI (HUD, payday, chat overlay) comes up.
func _begin_client_heist(info: Dictionary) -> void:
	_heist_id = StringName(info["heist"])
	_difficulty = int(info["difficulty"])
	is_pro = bool(info["is_pro"])
	last_breath = bool(info.get("last_breath", false))
	visible = false
	_spawn_in_heist_ui()
	# Co-op pass: the client's rows read "Host / AI 2"; the lobby's assignment is the host's (same summaries).
	if lobby != null and lobby.is_active():
		_set_heister_map(lobby.state.heister_assignment())
	if not Net.host_lost.is_connected(_on_client_host_lost):
		Net.host_lost.connect(_on_client_host_lost)


## C11: a client replica hears HeistNetSync.host_closed when the host tears its heist down (payday Continue).
func _watch_host_closed() -> void:
	var sync: Node = runtime.get(&"net_sync") as Node if runtime != null else null
	if sync != null and sync.has_signal(&"host_closed") and not sync.is_connected(&"host_closed", _on_client_host_closed):
		sync.connect(&"host_closed", _on_client_host_closed)


## The host closed the heist. On the payday nothing happens (its Continue returns to the lobby); a client
## still mid-heist (no payday reached it) goes back to the crew lobby with the session kept and says why.
func _on_client_host_closed() -> void:
	if _in_heist == null or (_heist_payday != null and is_instance_valid(_heist_payday) and _heist_payday.visible):
		return
	Log.info(&"ui", "host closed the heist; back to the crew lobby")
	_leave_heist(true)
	if lobby_screen != null:
		lobby_screen.error_label.text = UiText.t(&"ui.lobby.host_closed")


## net.md / HeistNetSync.host_lost: the connection to the host dropped while this client's replica runs.
## The app flow ends the heist here (teardown + Net.leave) and returns to the lobby's connect view with
## the reason, instead of leaving the player alone in a dead replica (co-op windowed pass). A payday
## already on screen (the heist ended, then the host closed) is left alone.
func _on_client_host_lost() -> void:
	if Net.host_lost.is_connected(_on_client_host_lost):
		Net.host_lost.disconnect(_on_client_host_lost)
	if _in_heist == null or (_heist_payday != null and is_instance_valid(_heist_payday) and _heist_payday.visible):
		return
	Log.warn(&"ui", "host lost during the heist; back to the lobby")
	_leave_heist()
	show_lobby()
	lobby_screen.error_label.text = UiText.t(&"ui.dropin.failed.host_lost")


## Lobby "Drop in to a running heist" (B6-04): the compact loadout pick + progress screen bound to DropInFlow.
func _open_drop_in(address: String, port: int) -> void:
	_free_screen(drop_in_screen)
	drop_in.lobby = lobby
	drop_in_screen = drop_in.open(address, port, _menu_profile(), profile_slot)
	drop_in_screen.visible = false
	add_child(drop_in_screen)
	drop_in_screen.back_requested.connect(_close_drop_in)
	drop_in_screen.joined.connect(_on_drop_in_joined)
	show_screen(drop_in_screen)


## Back / Cancel on the drop-in screen: back to the lobby's connect view, with the failure reason if any.
func _close_drop_in() -> void:
	_free_screen(drop_in_screen)
	drop_in_screen = null
	if drop_in.is_joining():
		drop_in.cancel_join()
	show_lobby()
	var reason: StringName = drop_in.last_failure
	if reason != &"" and reason != DropInService.REASON_CANCELLED:
		var key: StringName = StringName("ui.dropin.failed.%s" % reason)
		lobby_screen.error_label.text = UiText.t(key if DropInService.REASONS.has(reason) else &"ui.dropin.failed.unknown")


## A's service reports the local player in (its HeistLauncher.launch_client already built the replica): switch
## to the in-heist UI like a co-op client launch, without launching again.
func _on_drop_in_joined(_slot: int) -> void:
	_free_screen(drop_in_screen)
	drop_in_screen = null
	var info: Dictionary = drop_in.heist_info()
	_begin_client_heist(info)
	runtime = info["runtime"] as Object
	if runtime != null:
		_watch_host_closed()
		heist_launched.emit(runtime)


## Host launch of a co-op contract: the live session (no Net.start_solo; HeistLauncher fills empty
## slots with AI), every human slot's validated loadout, the host's confirmed plan and is_pro.
func launch_coop(info: Dictionary) -> void:
	var launcher: Script = UiNav.global_class(&"HeistLauncher")
	if launcher == null:
		_show_stub(&"ui.stub.launcher_missing", true)
		return
	_heist_id = info["heist"]
	_difficulty = int(info["difficulty"])
	is_pro = bool(info["is_pro"])
	last_breath = bool(info.get("last_breath", false))
	CrewLoadouts.source = _menu_profile()  # PO-19: the host's crew loadouts arm the bots
	var options: Dictionary = build_coop_launch_options(lobby.state.launch_loadouts(), preplan, is_pro,
			MusicCatalog.resolve_choice(_menu_profile()), Heisters.ai_loadouts(lobby.state.ai_heisters(), _menu_profile()),
			last_breath)
	DropInFlow.apply_host_policy(get_tree(), lobby.state.dropin_policy)  # B6-04: A's service decides drop-ins
	visible = false
	_spawn_in_heist_ui()
	_hand_heisters(options)
	runtime = await launcher.call(&"launch", _heist_id, int(info["seed"]), _difficulty, null, options)
	if runtime == null:
		Log.error(&"ui", "HeistLauncher.launch(%s) returned null (co-op); leaving" % _heist_id)
		_leave_heist()
		return
	heist_launched.emit(runtime)


## Co-op HeistLauncher options: `loadouts` = {slot: resolved Loadout} of the human slots
## (LobbyState.launch_loadouts()), `ai_teammates` = the seats left, plus `preplan` / `is_pro` as in
## build_launch_options(); `music_track` = the HOST's pick (host wins; ENV A replicates the options).
## D-073: `ai_loadouts` = {slot: Loadout} for the AI seats (Heisters.ai_loadouts(LobbyState.ai_heisters()): the
## default AI loadout with a heister left over), merged into `loadouts`; `ai_teammates` counts the seats humans leave.
static func build_coop_launch_options(loadouts: Dictionary, plan: Dictionary = {}, pro: bool = false,
		music: StringName = &"", ai_loadouts: Dictionary = {}, last_breath_on: bool = false) -> Dictionary:
	var all: Dictionary = loadouts.duplicate()
	all.merge(ai_loadouts)
	var options: Dictionary = {"ai_teammates": maxi(LobbyState.MAX_CREW - loadouts.size(), 0), "loadouts": all,
			"music_track": music}
	if not plan.is_empty():
		options["preplan"] = plan
	if pro:
		options["is_pro"] = true
	if last_breath_on:
		options["last_breath"] = true
	return options


static func _script_has_method(script: Script, method: StringName) -> bool:
	for m: Dictionary in script.get_script_method_list():
		if StringName(m["name"]) == method:
			return true
	return false
