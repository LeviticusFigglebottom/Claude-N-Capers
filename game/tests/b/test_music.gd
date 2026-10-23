## B5-03 music selection (D-062): MusicCatalog (stub fallback while ENV C's MusicTrackTable is missing,
## stable id order, unlock filtering, Notoriety unlock ranks), the launch option `music_track` (invalid /
## locked picks fall back to &""), the MusicPicker writing the profile (pre-planning, lobby state), the
## jukebox screen (Play disabled without MusicDirector.preview on this tree; a stand-in director node
## checks the call path) and the `jukebox` hub station.
extends TestCase

const JUKEBOX_SCENE: PackedScene = preload("res://content/ui/jukebox/jukebox_screen.tscn")
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const PREPLAN_SCENE: PackedScene = preload("res://content/ui/preplanning/preplanning_screen.tscn")
const SLOT: int = 0
const STUB_IDS: Array[StringName] = [
	&"dockside_burn", &"glasshouse", &"last_call", &"long_con", &"night_deposit", &"shadow_ledger", &"vault_hymn"]
## OF's track joins once OF is offered (round 245: hidden switch off); RT's with the D-160 flip.
const BASE_IDS: Array[StringName] = [&"dockside_burn", &"gallery_night", &"glasshouse", &"night_deposit",
	&"ostrander_federal", &"rolling_thunder", &"shadow_ledger"]
const NET_SCRIPT: Script = preload("res://core/net.gd")


## Test stand-in for ENV C's table: anything with all() -> Array.
class FakeTable:
	extends RefCounted
	var entries: Array = []

	func all() -> Array:
		return entries


## Test stand-in for the preview API (a plain node injected into the screen; C's class is not faked).
class FakeDirector:
	extends Node
	var calls: Array[String] = []

	func preview(track_id: StringName, stem: StringName = &"assault") -> bool:
		calls.append("preview:%s:%s" % [track_id, stem])
		return true

	func stop_preview() -> void:
		calls.append("stop")


var _branches: Array[Node] = []


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C's 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func before_each() -> void:
	MusicCatalog.table_override = null
	SaveService.delete_profile(SLOT)
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)


func after_each() -> void:
	MusicCatalog.table_override = null


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func _unlocked(ids: Array[StringName]) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new_default()
	for id: StringName in ids:
		p.unlocks.append(StringName("unlock.music.%s" % id))
	return p


# --- catalog -------------------------------------------------------------------------------------

func test_stub_fallback_while_the_table_is_missing() -> void:
	assert_eq(MusicCatalog.table_path(), "res://world/audio/music/tracks.tres", "D-062 path (data)")
	if ResourceLoader.exists(MusicCatalog.table_path()):
		assert_false(MusicCatalog.is_stub(), "C's table present: the stub is not used")
		return
	assert_true(MusicCatalog.is_stub(), "no MusicTrackTable on this tree -> stub")
	assert_eq(MusicCatalog.ids(), STUB_IDS, "stub ids in stable id order")
	assert_eq(MusicCatalog.track(&"vault_hymn")["unlock"], &"unlock.music.vault_hymn")
	assert_eq(MusicCatalog.track(&"glasshouse")["unlock"], &"")
	assert_eq(MusicCatalog.default_for(&"glasshouse"), &"glasshouse")
	assert_eq(MusicCatalog.default_for(&"nope"), &"")
	assert_true(MusicCatalog.track(&"nope").is_empty())
	assert_false(MusicCatalog.has(&""))


func test_every_heist_default_track_is_in_the_catalog_with_a_name() -> void:
	var table: Dictionary = StringTable.parse_csv()
	for hid: StringName in HeistCatalog.ids():
		var def: HeistDef = HeistRegistry.get_def(hid)
		if def == null or def.music_track == &"":
			continue
		assert_true(MusicCatalog.has(def.music_track), "HeistDef.music_track %s listed" % def.music_track)
	for id: StringName in MusicCatalog.ids():
		assert_has(table, String(MusicCatalog.display_key(id)), "name string for %s" % id)
	assert_has(table, String(MusicCatalog.DEFAULT_KEY))


func test_table_entries_are_duck_typed_sorted_and_deduplicated() -> void:
	var fake: FakeTable = FakeTable.new()
	var res: MusicStubTrack = MusicStubTrack.new()
	res.id = &"beta"
	res.unlock = &"unlock.music.beta"
	fake.entries = [
		{"id": &"gamma", "unlock": &"", "default_for_heists": [&"glasshouse"]},
		res,
		{"id": "alpha", "unlock": "", "default_for_heists": PackedStringArray(["night_deposit"])},
		{"id": &"gamma", "unlock": &"unlock.music.other"},
		{"id": &""},
		42,
	]
	MusicCatalog.table_override = fake
	assert_false(MusicCatalog.is_stub())
	assert_eq(MusicCatalog.ids(), [&"alpha", &"beta", &"gamma"] as Array[StringName], "sorted by id, first entry wins")
	assert_eq(MusicCatalog.track(&"gamma")["unlock"], &"", "the first gamma entry is kept")
	assert_eq(MusicCatalog.default_for(&"night_deposit"), &"alpha", "PackedStringArray heists read too")
	var t: Dictionary = MusicCatalog.track(&"alpha")
	assert_true(t["id"] is StringName and t["unlock"] is StringName, "ids are StringNames")
	assert_eq(MusicCatalog.available(PlayerProfile.new_default()), [&"alpha", &"gamma"] as Array[StringName])


func test_unlock_filtering_and_notoriety_ranks() -> void:
	var fresh: PlayerProfile = PlayerProfile.new_default()
	assert_eq(MusicCatalog.available(fresh), BASE_IDS, "only always-owned tracks")
	assert_false(MusicCatalog.is_unlocked(fresh, &"vault_hymn"))
	assert_false(MusicCatalog.is_unlocked(fresh, &"nope"), "unknown -> locked")
	assert_true(MusicCatalog.is_unlocked(fresh, &"night_deposit"))
	var vet: PlayerProfile = _unlocked([&"vault_hymn", &"last_call"])
	var want: Array[StringName] = [&"dockside_burn", &"gallery_night", &"glasshouse", &"last_call", &"night_deposit",
		&"ostrander_federal", &"rolling_thunder", &"shadow_ledger", &"vault_hymn"]  # LEAD
	assert_eq(MusicCatalog.available(vet), want)
	assert_eq(MusicCatalog.unlock_rank(&"vault_hymn"), 7)
	assert_eq(MusicCatalog.unlock_rank(&"long_con"), 13)
	assert_eq(MusicCatalog.unlock_rank(&"last_call"), 21)
	assert_eq(MusicCatalog.unlock_rank(&"glasshouse"), 0)
	assert_eq(MusicCatalog.display_key(&"vault_hymn"), &"music.vault_hymn.name")
	assert_eq(MusicCatalog.display_key(&""), &"ui.music.heist_default")
	assert_eq(UiText.t(&"music.vault_hymn.name"), "Vault Hymn")


func test_notoriety_rank_up_unlocks_its_track() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.notoriety = 6
	p.level = 100
	p.xp = XpCurve.xp_for_level(100)
	p.cash = Notoriety.cost_for(7)
	assert_false(MusicCatalog.is_unlocked(p, &"vault_hymn"))
	assert_true(bool(Notoriety.rank_up(p)["ok"]), "rank VII")
	assert_true(MusicCatalog.is_unlocked(p, &"vault_hymn"), "rank VII grants unlock.music.vault_hymn")


func test_resolve_choice_falls_back_to_heist_default() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(MusicCatalog.resolve_choice(p), &"")
	p.music_choice = &"night_deposit"
	assert_eq(MusicCatalog.resolve_choice(p), &"night_deposit")
	p.music_choice = &"vault_hymn"
	assert_eq(MusicCatalog.resolve_choice(p), &"", "locked -> heist default")
	p.music_choice = &"removed_track"
	assert_eq(MusicCatalog.resolve_choice(p), &"", "unknown -> heist default")
	assert_eq(MusicCatalog.resolve_choice(null), &"")


# --- launch options ------------------------------------------------------------------------------

func test_launch_options_carry_music_track() -> void:
	var l: Loadout = LoadoutResolver.resolve(PlayerProfile.new_default().loadout)
	var solo: Dictionary = MenuFlow.build_launch_options(3, 0, l, {}, false, &"night_deposit")
	assert_eq(solo["music_track"], &"night_deposit")
	assert_eq(MenuFlow.build_launch_options(3, 0, l)["music_track"], &"", "always present; empty = heist default")
	var coop: Dictionary = MenuFlow.build_coop_launch_options({0: l}, {}, false, &"glasshouse")
	assert_eq(coop["music_track"], &"glasshouse", "the host's pick")
	assert_eq(MenuFlow.build_coop_launch_options({0: l})["music_track"], &"")


func test_flow_launch_options_use_the_profile_pick_or_fall_back() -> void:
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await wait_frames(1)
	var p: PlayerProfile = PlayerProfile.new_default()
	f.profile = p
	p.music_choice = &"shadow_ledger"
	assert_eq(f.launch_options_for(p.loadout)["music_track"], &"shadow_ledger")
	p.music_choice = &"long_con"
	assert_eq(f.launch_options_for(p.loadout)["music_track"], &"", "locked pick -> heist default")
	p.unlocks.append(&"unlock.music.long_con")
	assert_eq(f.launch_options_for(p.loadout)["music_track"], &"long_con", "unlocked now")
	p.music_choice = &"gone"
	assert_eq(f.launch_options_for(p.loadout)["music_track"], &"", "unknown pick -> heist default")
	f.queue_free()
	await wait_frames(1)


# --- picker --------------------------------------------------------------------------------------

func test_picker_lists_tracks_and_writes_the_profile() -> void:
	var p: PlayerProfile = _unlocked([&"vault_hymn"])
	var mp: MusicPicker = MusicPicker.new()
	mp.profile_slot = SLOT
	mp.setup(p, &"night_deposit")
	add_child(mp)
	await wait_frames(1)
	assert_eq(mp.item_ids.size(), 1 + MusicCatalog.ids().size(), "heist default + every track")
	assert_eq(mp.option.get_item_text(0), UiText.t(&"ui.music.heist_default_named", {"name": "Time Lock"}))
	assert_eq(mp.selected_id(), &"")
	var long_con: int = mp.item_ids.find(&"long_con")
	assert_true(mp.option.is_item_disabled(long_con), "locked track disabled")
	assert_eq(mp.option.get_item_text(long_con), UiText.t(&"ui.music.locked_rank", {"name": "The Long Con", "rank": "XIII"}))
	assert_false(mp.option.is_item_disabled(mp.item_ids.find(&"vault_hymn")), "unlocked by Notoriety")
	var heard: Array[StringName] = []
	mp.music_changed.connect(func(id: StringName) -> void: heard.append(id))
	assert_true(mp.choose(&"vault_hymn"))
	assert_eq(p.music_choice, &"vault_hymn")
	assert_eq(SaveService.load_profile(SLOT).music_choice, &"vault_hymn", "saved")
	assert_eq(mp.selected_id(), &"vault_hymn")
	assert_false(mp.choose(&"long_con"), "locked")
	assert_false(mp.choose(&"nope"), "unknown")
	assert_eq(p.music_choice, &"vault_hymn", "unchanged by refused picks")
	mp.option.select(mp.item_ids.find(&"glasshouse"))
	mp.option.item_selected.emit(mp.item_ids.find(&"glasshouse"))
	assert_eq(p.music_choice, &"glasshouse", "list selection writes the pick")
	assert_true(mp.choose(&""))
	assert_eq(SaveService.load_profile(SLOT).music_choice, &"", "back to heist default")
	assert_eq(heard, [&"vault_hymn", &"glasshouse", &""] as Array[StringName])
	mp.set_read_only(&"night_deposit")
	assert_false(mp.option.visible)
	assert_true(mp.value_label.visible)
	assert_eq(mp.value_label.text, "Time Lock")
	assert_false(mp.choose(&"glasshouse"), "read-only")
	mp.queue_free()
	await wait_frames(1)


func test_picker_shows_heist_default_for_a_stale_pick() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.music_choice = &"last_call"
	var mp: MusicPicker = MusicPicker.new()
	mp.setup(p)
	add_child(mp)
	await wait_frames(1)
	assert_eq(mp.selected_id(), &"", "locked pick shows as heist default")
	assert_eq(mp.option.get_item_text(0), UiText.t(&"ui.music.heist_default"))
	mp.queue_free()
	await wait_frames(1)


func test_preplanning_screen_has_the_music_pick() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var s: PreplanningScreen = PREPLAN_SCENE.instantiate() as PreplanningScreen
	s.profile_slot = SLOT
	s.setup(&"glasshouse", Enums.Difficulty.ROUTINE, p)
	add_child(s)
	await wait_frames(2)
	assert_true(s.music_picker != null, "solo: music pick shown")
	assert_eq(s.confirm_button.focus_neighbor_left, s.confirm_button.get_path_to(s.music_picker.option),
			"focus reaches it (PO-4: Back, Music, Confirm)")
	assert_true(s.music_picker.choose(&"shadow_ledger"))
	assert_eq(s.profile.music_choice, &"shadow_ledger")
	assert_eq(SaveService.load_profile(SLOT).music_choice, &"shadow_ledger")
	s.queue_free()
	var c: PreplanningScreen = PREPLAN_SCENE.instantiate() as PreplanningScreen
	c.music_enabled = false
	c.setup(&"glasshouse", Enums.Difficulty.ROUTINE, p)
	add_child(c)
	await wait_frames(2)
	assert_true(c.music_picker == null, "co-op client: no pick")
	c.queue_free()
	await wait_frames(1)


func test_lobby_summary_carries_the_host_pick() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.music_choice = &"night_deposit"
	var sum: Dictionary = LobbyState.sanitize_summary(LobbyState.summary_from(p.loadout, p))
	assert_eq(sum["music"], "night_deposit")
	assert_true(LobbyState.is_json_safe(LobbyState.summary_from(p.loadout, p)))
	p.music_choice = &"vault_hymn"
	assert_eq(LobbyState.summary_from(p.loadout, p)["music"], "", "locked pick is not advertised")
	var raw: Dictionary = LobbyState.summary_from(p.loadout, p)
	raw.erase("music")
	assert_eq(LobbyState.sanitize_summary(raw)["music"], "", "missing -> heist default")
	raw["music"] = 7
	assert_false(LobbyState.sanitize_summary(raw).is_empty(), "a bad music field never drops the summary")
	assert_eq(LobbyState.sanitize_summary(raw)["music"], "")
	var st: LobbyState = LobbyState.new(false)
	st.set_crew({0: {"peer_id": 1, "is_ai": false, "display_name": "Host"}, 1: {"peer_id": 2, "is_ai": false,
			"display_name": "Me"}}, 1, 0)
	assert_eq(st.host_music(), &"")
	p.music_choice = &"glasshouse"
	assert_eq(st.receive(0, LobbyState.MSG_PROFILE, LobbyState.summary_from(p.loadout, p)), LobbyState.OK)
	assert_eq(st.host_music(), &"glasshouse")
	assert_eq(st.slot_view(0)["music"], &"glasshouse")


# --- jukebox -------------------------------------------------------------------------------------

func _jukebox(p: PlayerProfile) -> JukeboxScreen:
	var s: JukeboxScreen = JUKEBOX_SCENE.instantiate() as JukeboxScreen
	s.setup(p)
	add_child(s)
	return s


## D-062 on trunk: C's MusicDirector.preview(track_id, stem) -> bool / stop_preview(). The jukebox instances a
## bare director (listen_to_event_bus = false); Play is enabled for unlocked tracks. preview() returns false for
## tracks without stems (only glasshouse has stems until C5-01), and then nothing is "playing".
func test_jukebox_with_the_real_preview_api() -> void:
	assert_true(JukeboxScreen.preview_available(), "C's MusicDirector.preview is on this tree")
	var s: JukeboxScreen = _jukebox(_unlocked([&"long_con"]))
	await wait_frames(2)
	assert_true(s.director != null, "a preview director is instanced")
	assert_false(bool(s.director.get(&"listen_to_event_bus")), "bare director: no heist phase listening")
	assert_false(s.notice_label.visible, "no 'previews arrive later' notice")
	assert_eq(s.play_buttons.size(), MusicCatalog.ids().size(), "one row per track")
	assert_false((s.play_buttons[&"glasshouse"] as Button).disabled, "Play enabled for an owned track")
	assert_true((s.play_buttons[&"vault_hymn"] as Button).disabled, "locked track stays disabled")
	assert_true(s.play(&"glasshouse"), "glasshouse has stems")
	assert_eq(s.now_playing, &"glasshouse")
	assert_false(s.stop_button.disabled)
	s.stop()
	assert_eq(s.now_playing, &"")
	for id: StringName in MusicCatalog.ids():
		if id == &"glasshouse" or not MusicCatalog.is_unlocked(s.profile, id):
			continue
		var ok: bool = s.play(id)
		if not ok:
			assert_eq(s.now_playing, &"", "%s without stems: nothing playing" % id)
		s.stop()
	s.queue_free()
	await wait_frames(1)


func test_jukebox_drives_a_director_and_stops_on_leave() -> void:
	var s: JukeboxScreen = _jukebox(PlayerProfile.new_default())
	await wait_frames(2)
	var d: FakeDirector = FakeDirector.new()
	s.add_child(d)
	s.director = d
	s.refresh()
	assert_false((s.play_buttons[&"glasshouse"] as Button).disabled)
	assert_true((s.play_buttons[&"vault_hymn"] as Button).disabled, "locked")
	assert_false(s.play(&"vault_hymn"), "locked track does not play")
	(s.play_buttons[&"night_deposit"] as Button).pressed.emit()
	assert_eq(s.now_playing, &"night_deposit")
	assert_eq(d.calls, ["preview:night_deposit:assault"] as Array[String])
	assert_eq(s.now_label.text, UiText.t(&"ui.jukebox.now_playing", {"name": "Time Lock"}))
	assert_false(s.stop_button.disabled)
	s.stop_button.pressed.emit()
	assert_eq(s.now_playing, &"")
	assert_eq(d.calls.back(), "stop")
	assert_true(s.play(&"glasshouse"))
	var backs: Array[int] = [0]
	s.back_requested.connect(func() -> void: backs[0] += 1)
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	s._unhandled_input(esc)
	assert_eq(backs[0], 1, "Esc / B -> back")
	assert_eq(s.now_playing, &"", "leaving stops the preview")
	assert_eq(d.calls.back(), "stop")
	assert_true(s.play(&"glasshouse"))
	s.visible = false
	assert_eq(s.now_playing, &"", "hiding stops the preview")
	s.queue_free()
	await wait_frames(1)


func test_jukebox_station_opens_from_the_hub() -> void:
	var list: HubStationList = HubStationList.load_default()
	assert_eq(list.find(&"jukebox").target, MenuFlow.TARGET_JUKEBOX)
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await wait_frames(1)
	f.main_menu.safehouse_button.pressed.emit()
	await wait_frames(2)
	f.hub.station_button(&"jukebox").pressed.emit()
	await wait_frames(2)
	assert_true(f.current is JukeboxScreen, "jukebox station")
	var s: JukeboxScreen = f.current as JukeboxScreen
	assert_eq(s.play_buttons.size(), MusicCatalog.ids().size())
	s.back_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.hub as Control, "Back -> hub")
	assert_false(is_instance_valid(s) and s.is_inside_tree(), "the screen is freed")
	assert_true(f.open_station(&"jukebox"))
	await wait_frames(1)
	assert_true(f.current is JukeboxScreen)
	f.queue_free()
	await wait_frames(1)


# --- lobby (host picks, clients see it read-only) -------------------------------------------------

func _branch(branch_name: String) -> Node:
	var root: Node = Node.new()
	root.name = branch_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var n: Node = NET_SCRIPT.new() as Node
	n.name = "Net"
	root.add_child(n)
	_branches.append(root)
	return n


func _drop_branches() -> void:
	for b: Node in _branches:
		var n: Node = b.get_node_or_null(^"Net")
		if n != null:
			n.call(&"leave")
		get_tree().set_multiplayer(null, b.get_path())
		b.queue_free()
	_branches.clear()
	await wait_frames(2)


func _coop_flow(net: Node) -> MenuFlow:
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	f.lobby = LobbySession.new()
	f.lobby.net = net
	add_child(f)
	return f


func test_lobby_host_picks_and_client_sees_it() -> void:
	var port: int = 20000 + (OS.get_process_id() + 11) % 20000
	var host: MenuFlow = _coop_flow(_branch("HostBranch"))
	await wait_frames(2)
	host.open_station(&"crew")
	await wait_frames(2)
	var hls: LobbyScreen = host.lobby_screen
	hls.host_port_edit.text = str(port)
	assert_eq(hls.host(), OK)
	await wait_frames(2)
	assert_true(hls.music_picker.editable and hls.music_picker.option.visible, "host: editable pick")
	assert_has(hls.focus_chain, hls.music_picker.option as Control)
	assert_true(hls.music_picker.choose(&"night_deposit"))
	assert_eq(host.profile.music_choice, &"night_deposit")
	assert_true(await wait_until(func() -> bool: return host.lobby.state.host_music() == &"night_deposit", 5.0),
			"host summary re-sent with the pick")
	var client: LobbySession = LobbySession.new()
	client.net = _branch("ClientBranch")
	client.profile = PlayerProfile.new_default()
	add_child(client)
	var cls: LobbyScreen = (load("res://content/ui/lobby/lobby_screen.tscn") as PackedScene).instantiate() as LobbyScreen
	cls.setup(client, client.profile)
	add_child(cls)
	assert_eq(client.join("127.0.0.1", port), OK)
	assert_true(await wait_until(func() -> bool: return client.state.host_music() == &"night_deposit", 10.0),
			"the host's pick reached the client")
	await wait_frames(2)
	assert_false(cls.music_picker.editable, "client: read-only")
	assert_false(cls.music_picker.option.visible)
	assert_eq(cls.music_picker.value_label.text, "Time Lock")
	assert_false(cls.focus_chain.has(cls.music_picker.option as Control))
	var opts: Dictionary = MenuFlow.build_coop_launch_options(host.lobby.state.launch_loadouts(), {}, false,
			MusicCatalog.resolve_choice(host.profile))
	assert_eq(opts["music_track"], &"night_deposit", "host wins")
	cls.queue_free()
	client.queue_free()
	host.queue_free()
	await _drop_branches()

