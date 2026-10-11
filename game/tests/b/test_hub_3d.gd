## B6-06 (QC-45..49): MenuFlow's 3D safehouse hub mode against a MOCK safehouse scene
## (tests/b/mock_safehouse/: a MockSafehouseMap root, stations in group hub_station under Stations/ with
## UsePoints, a walker stand-in in group hub_walker, a mock jukebox cabinet). Covers enter -> interact ->
## screen -> walker paused -> close -> back at the UsePoint, the StationCam blend, A's station_used(id, crew)
## and the root signal, the 2D fallback, the Options toggle, the pause menu and the jukebox routing.
extends TestCase

const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const MOCK_SCENE: String = "res://tests/b/mock_safehouse/mock_safehouse.tscn"
const MOCK_CLASS: StringName = &"MockSafehouseMap"
const HUB_KEY: StringName = &"safehouse_hub"
## Not a class: SafehouseHost then uses the mock scene's walker stand-in (group hub_walker).
const NO_CREW_CLASS: StringName = &"NoSuchCrewClass"
## A physics body settles after a teleport (gravity, collision): horizontal tolerance in m.
const CREW_TOL_M: float = 0.05


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR
	_set_hub_mode("walk")


func before_each() -> void:
	SaveService.delete_profile(0)
	var p: PlayerProfile = PlayerProfile.new_default()
	p.music_choice = &"glasshouse"
	SaveService.save_profile(p, 0)
	_set_hub_mode("walk")


static func _set_hub_mode(mode: String) -> void:
	GameSettings.current().set_value(GameSettings.CONTROLS, HUB_KEY, mode)


## A MenuFlow whose safehouse tweak points at the mock scene (`scene_path` "" = the shipped data). The mock
## walker stand-in is forced (crew_class -> NO_CREW_CLASS) unless `real_crew`: ENV A's hub crew (A3-11) is a
## CharacterBody3D with its own API, covered by test_real_hub_crew.
func _flow(scene_path: String = MOCK_SCENE, blend_s: float = 0.0, map_class: StringName = MOCK_CLASS,
		real_crew: bool = false) -> MenuFlow:
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	if scene_path != "":
		var t: SafehouseHubTweak = SafehouseHubTweak.load_default().duplicate() as SafehouseHubTweak
		t.scene_path = scene_path
		t.map_class = map_class
		t.station_cam_blend_s = blend_s
		if not real_crew:
			t.crew_class = NO_CREW_CLASS
		f.safehouse.tweak = t
	return f


func _enter(f: MenuFlow) -> void:
	await wait_frames(1)
	f.main_menu.safehouse_button.pressed.emit()
	await wait_frames(2)


func _walker(f: MenuFlow) -> Node3D:
	return f.safehouse.walker as Node3D


func _station(f: MenuFlow, id: StringName) -> Node:
	return f.safehouse.station_node(id)


func _marker(f: MenuFlow, path: String) -> Vector3:
	return (f.safehouse.map.get_node(NodePath(path)) as Node3D).global_position


func _done(f: MenuFlow) -> void:
	f.queue_free()
	await wait_frames(1)


func test_data_toggle_and_strings() -> void:
	var t: SafehouseHubTweak = SafehouseHubTweak.load_default()
	assert_eq(t.scene_path, "res://world/hub/safehouse/safehouse.tscn", "C's scene path is data")
	assert_eq(t.map_class, &"SafehouseMap")
	assert_eq(t.spawn_marker, &"Spawn", "hub_map.md: unknown return ids fall back to Spawn")
	assert_eq(t.duck_method, &"set_ducked")
	assert_near(t.station_cam_fov, 60.0, 0.0001, "hub_map.md: StationCam fov default")
	assert_near(t.station_cam_blend_s, 0.35, 0.0001)
	var s: GameSettings = GameSettings.new()
	assert_true(s.hub_walk(), "walk is the default")
	s.set_value(GameSettings.CONTROLS, HUB_KEY, "menu")
	assert_false(s.hub_walk())
	assert_eq(s.set_value(GameSettings.CONTROLS, HUB_KEY, "jetpack"), "walk", "unknown value -> default")
	var table: Dictionary = StringTable.parse_csv()
	assert_has(table, String(OptionsRows.label_key(GameSettings.CONTROLS, HUB_KEY)))
	for o: String in ["walk", "menu"]:
		assert_has(table, String(OptionsRows.option_key(GameSettings.CONTROLS, HUB_KEY, o)))
	for id: StringName in HubStationList.load_default().ids():
		assert_has(table, "ui.prompt.station.%s" % id, "QC-47 prompt for %s" % id)
	for k: String in ["ui.hub.pause.title", "ui.hub.pause.resume", "ui.hub.pause.quick_stations"]:
		assert_has(table, k)
	# hub_map.md v1.0: same prompt format as the in-heist interactions ("Press {key} to ...").
	assert_eq(UiText.t(&"ui.prompt.station.board", {"key": "F"}), "Press F to check the Board")
	for id: StringName in HubStationList.load_default().ids():
		var text: String = UiText.t(StringName("ui.prompt.station.%s" % id), {"key": "F"})
		assert_true(text.begins_with("Press F to ") or text.begins_with("Hold F to "), "in-heist prompt format: %s" % text)


func test_options_screen_has_the_toggle() -> void:
	var o: OptionsScreen = (load("res://content/ui/menus/options_screen.tscn") as PackedScene).instantiate() as OptionsScreen
	o.settings = GameSettings.new()
	o.save_on_apply = false
	add_child(o)
	await wait_frames(1)
	var row: Node = o.find_child("Row_%s" % HUB_KEY, true, false)
	assert_true(row != null, "Controls tab lists the safehouse toggle")
	var ob: OptionButton = row.find_child("Choice", true, false) as OptionButton
	assert_eq(ob.item_count, 2)
	ob.select(1)
	ob.item_selected.emit(1)
	assert_false(o.draft.hub_walk(), "picking Station Menu writes the draft")
	o.queue_free()
	await wait_frames(1)


func test_falls_back_to_the_2d_hub_when_the_scene_is_missing() -> void:
	var f: MenuFlow = _flow("")  # shipped data: C's scene is not on this tree yet
	await _enter(f)
	if not f.safehouse.scene_available():
		assert_eq(f.current, f.hub as Control, "2D hub fallback")
		assert_false(f.safehouse.is_active())
		assert_true(f.background.visible and f.background.color.a > 0.99, "opaque menu backdrop")
	await _done(f)
	var g: MenuFlow = _flow("res://tests/b/mock_safehouse/missing.tscn")
	await _enter(g)
	assert_eq(g.current, g.hub as Control, "missing scene -> 2D hub")
	await _done(g)
	var h: MenuFlow = _flow(MOCK_SCENE, 0.0, &"NoSuchSafehouseClass")
	await _enter(h)
	assert_eq(h.current, h.hub as Control, "root class missing -> 2D hub")
	assert_false(h.safehouse.is_active())
	await _done(h)


func test_enter_interact_close_returns_to_the_use_point() -> void:
	var f: MenuFlow = _flow()
	await _enter(f)
	var sh: SafehouseHost = f.safehouse
	assert_true(sh.is_active(), "3D safehouse entered")
	assert_eq(f.current, sh.hud as Control, "hub HUD shown")
	assert_false(f.hub.visible, "2D hub hidden")
	var w: Node3D = _walker(f)
	assert_true(w != null)
	assert_true(w.global_position.is_equal_approx(_marker(f, "Spawns/ReturnHeist")), "spawned at ReturnHeist")
	assert_false(bool(w.get(&"paused")))
	assert_false(sh.mouse_released, "mouse captured while walking")
	assert_eq(f.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the flow lets mouse look through")
	assert_false(f.background.visible, "no backdrop over the 3D view while walking")
	assert_eq((sh.map as MockSafehouseMap).jukebox_tracks.back(), &"glasshouse", "cabinet plays the saved pick")
	# HUD prompt from the walker's interaction.
	w.call(&"focus", &"board")
	assert_eq(sh.hud.prompt_text(), UiText.t(&"ui.prompt.station.board", {"key": InteractionPanel.action_key_text(&"interact")}))
	w.call(&"focus", &"")
	assert_eq(sh.hud.prompt_text(), "")
	# Use the armory from somewhere else in the room.
	w.global_position = Vector3(20, 0, 5)
	_station(f, &"armory").call(&"use")
	await wait_frames(2)
	assert_eq(f.current, f.loadout_screen as Control, "armory screen opened")
	assert_true(f.loadout_screen.hub_mode)
	assert_true(bool(w.get(&"paused")), "walker paused behind the screen")
	assert_true(sh.input_paused)
	assert_true(sh.mouse_released)
	assert_eq(f.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_true(f.background.visible and f.background.color.a < 1.0, "3D view dimmed behind the screen")
	f.loadout_screen.back_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, sh.hud as Control, "Back -> walking again")
	assert_false(bool(w.get(&"paused")))
	assert_true(w.global_position.is_equal_approx(_marker(f, "Stations/armory/UsePoint")), "back at the armory UsePoint")
	assert_eq(sh.station_id, &"")
	assert_false(sh.mouse_released)
	await _done(f)


func test_station_signals_from_prefab_and_root() -> void:
	var f: MenuFlow = _flow()
	await _enter(f)
	var sh: SafehouseHost = f.safehouse
	# A's hub_station prefab shape: station_used(id, crew).
	_station(f, &"notoriety").call(&"use", sh.walker)
	await wait_frames(2)
	assert_true(f.current is NotorietyScreen, "QC-46 notoriety station -> NotorietyScreen")
	(f.current as UiScreen).back_requested.emit()
	await wait_frames(2)
	assert_eq(f.current, sh.hud as Control)
	assert_true(_walker(f).global_position.is_equal_approx(_marker(f, "Stations/notoriety/UsePoint")))
	# C's root signal.
	sh.map.emit_signal(&"station_requested", &"board")
	await wait_frames(2)
	assert_eq(f.current, f.board_screen as Control, "root station_requested -> the Board")
	# A second request while a screen is open is ignored.
	_station(f, &"armory").call(&"use")
	await wait_frames(1)
	assert_eq(f.current, f.board_screen as Control, "no station switch from behind a screen")
	f.board_screen.back_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, sh.hud as Control)
	assert_true(_walker(f).global_position.is_equal_approx(_marker(f, "Stations/board/UsePoint")))
	await _done(f)


func test_station_cam_blend_before_the_screen() -> void:
	var f: MenuFlow = _flow(MOCK_SCENE, 0.1)
	await _enter(f)
	var sh: SafehouseHost = f.safehouse
	var walker_cam: Camera3D = _walker(f).get_node(^"Camera") as Camera3D
	assert_true(walker_cam.current, "walker camera active")
	var home: Transform3D = walker_cam.transform
	var home_fov: float = walker_cam.fov
	_station(f, &"board").call(&"use")
	await wait_frames(1)
	assert_true(sh.map.find_children("*", "Camera3D", true, false).size() == 1, "no extra camera: the walker's own blends")
	assert_true(walker_cam.current, "the walker camera stays current")
	assert_eq(f.current, sh.hud as Control, "screen waits for the blend")
	await get_tree().create_timer(0.3).timeout
	assert_eq(f.current, f.board_screen as Control, "screen opens after the blend")
	var marker: Node3D = sh.map.get_node(^"Stations/board/StationCam") as Node3D
	assert_true(marker is Marker3D, "StationCam is a Marker3D (hub_map.md v1.0)")
	assert_true(walker_cam.global_position.is_equal_approx(marker.global_position), "blend ends on StationCam")
	assert_true((-walker_cam.global_basis.z).is_equal_approx(-marker.global_basis.z), "-Z = view direction")
	assert_near(walker_cam.fov, 50.0, 0.01, "FOV from the marker's fov meta")
	f.board_screen.back_button.pressed.emit()
	await wait_frames(2)
	assert_true(walker_cam.current, "walker camera current")
	assert_true(walker_cam.transform.is_equal_approx(home), "camera transform restored")
	assert_near(walker_cam.fov, home_fov, 0.01, "camera FOV restored")
	assert_true(_walker(f).global_position.is_equal_approx(_marker(f, "Stations/board/UsePoint")), "back at the UsePoint")
	await _done(f)


func test_station_cam_fov_default_and_unknown_spawn_fallback() -> void:
	var f: MenuFlow = _flow(MOCK_SCENE, 0.05)
	await _enter(f)
	var sh: SafehouseHost = f.safehouse
	(sh.map.get_node(^"Stations/board/StationCam") as Node).remove_meta(&"fov")
	var walker_cam: Camera3D = _walker(f).get_node(^"Camera") as Camera3D
	_station(f, &"board").call(&"use")
	await get_tree().create_timer(0.2).timeout
	assert_near(walker_cam.fov, 60.0, 0.01, "no fov meta -> 60 degrees")
	f.board_screen.back_button.pressed.emit()
	await wait_frames(2)
	var spawn: Vector3 = _marker(f, "Spawns/Spawn")
	assert_true(sh.spawn_transform(&"NoSuchMarker").origin.is_equal_approx(spawn), "root: unknown id -> Spawn")
	assert_true(SafehouseHost.marker_transform(sh.map, &"NoSuchMarker", &"Spawn").origin.is_equal_approx(spawn),
		"host fallback (root without spawn_transform): unknown id -> Spawn")
	assert_true(SafehouseHost.marker_transform(sh.map, &"ReturnRange", &"Spawn").origin.is_equal_approx(
		_marker(f, "Spawns/ReturnRange")), "known marker by name")
	f.safehouse.leave(&"NoSuchMarker")
	f.show_home()
	await wait_frames(1)
	assert_true(_walker(f).global_position.is_equal_approx(_marker(f, "Spawns/Spawn")), "never stranded: Spawn")
	await _done(f)


func test_cabinet_ducks_under_station_screens_but_not_the_jukebox() -> void:
	var f: MenuFlow = _flow()
	await _enter(f)
	var sh: SafehouseHost = f.safehouse
	var cabinet: Node = sh.jukebox()
	_station(f, &"armory").call(&"use")
	await wait_frames(2)
	assert_true(sh.ducked, "armory screen ducks the cabinet")
	assert_eq((cabinet.get(&"calls") as Array[String]).back(), "duck:true")
	f.loadout_screen.back_button.pressed.emit()
	await wait_frames(2)
	assert_false(sh.ducked)
	assert_eq((cabinet.get(&"calls") as Array[String]).back(), "duck:false", "un-ducked on return")
	# Quick stations from the pause menu duck too.
	sh.open_pause()
	sh.pause_menu.station_button(&"notoriety").pressed.emit()
	await wait_frames(2)
	assert_true(sh.ducked, "quick station ducks")
	(f.current as UiScreen).back_requested.emit()
	await wait_frames(2)
	assert_false(sh.ducked)
	(cabinet.get(&"calls") as Array[String]).clear()
	_station(f, &"jukebox").call(&"use")
	await wait_frames(2)
	assert_false(sh.ducked, "the jukebox screen never ducks its own previews")
	assert_false((cabinet.get(&"calls") as Array[String]).has("duck:true"))
	await _done(f)


func test_options_toggle_switches_to_the_2d_hub() -> void:
	_set_hub_mode("menu")
	var f: MenuFlow = _flow()
	await _enter(f)
	assert_eq(f.current, f.hub as Control, "menu mode -> 2D hub")
	assert_false(f.safehouse.is_active())
	_set_hub_mode("walk")
	f.show_hub()
	await wait_frames(1)
	assert_eq(f.current, f.safehouse.hud as Control, "walk mode -> 3D")
	_set_hub_mode("menu")
	f.show_hub()
	await wait_frames(1)
	assert_eq(f.current, f.hub as Control, "switching back leaves the safehouse")
	assert_false(f.safehouse.is_active())
	assert_true(f.background.visible and f.background.color.a > 0.99)
	assert_eq(f.mouse_filter, Control.MOUSE_FILTER_STOP)
	await _done(f)


func test_pause_menu_quick_stations_options_and_main_menu() -> void:
	var f: MenuFlow = _flow()
	await _enter(f)
	var sh: SafehouseHost = f.safehouse
	var w: Node3D = _walker(f)
	w.global_position = Vector3(12, 0, 6)
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	sh.hud._unhandled_input(esc)
	await wait_frames(1)
	assert_eq(f.current, sh.pause_menu as Control, "Esc -> pause menu")
	assert_true(bool(w.get(&"paused")))
	assert_true(sh.mouse_released)
	assert_eq(sh.pause_menu.station_buttons.size(), f.stations.ids().size(), "a quick button per station")
	# Quick station: straight to its screen; Back resumes on the spot.
	sh.pause_menu.station_button(&"notoriety").pressed.emit()
	await wait_frames(2)
	assert_true(f.current is NotorietyScreen)
	(f.current as UiScreen).back_requested.emit()
	await wait_frames(2)
	assert_eq(f.current, sh.hud as Control)
	assert_false(bool(w.get(&"paused")))
	assert_true(w.global_position.is_equal_approx(Vector3(12, 0, 6)), "quick station keeps the position")
	# Options and back to the pause menu.
	sh.open_pause()
	sh.pause_menu.options_button.pressed.emit()
	await wait_frames(2)
	assert_true(f.current is OptionsScreen)
	(f.current as OptionsScreen).back_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, sh.pause_menu as Control, "Options Back -> pause menu")
	sh.pause_menu.resume_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, sh.hud as Control, "Resume -> walking")
	assert_false(bool(w.get(&"paused")))
	# Main menu leaves the safehouse.
	sh.open_pause()
	sh.pause_menu.main_menu_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.main_menu as Control)
	assert_false(sh.is_active(), "safehouse freed")
	assert_true(f.background.visible and f.background.color.a > 0.99)
	await _done(f)


func test_jukebox_previews_through_the_cabinet() -> void:
	var f: MenuFlow = _flow()
	await _enter(f)
	var sh: SafehouseHost = f.safehouse
	var cabinet: Node = sh.jukebox()
	assert_true(cabinet != null and cabinet == (sh.map as MockSafehouseMap).jukebox, "the root's jukebox")
	_station(f, &"jukebox").call(&"use")
	await wait_frames(2)
	var s: JukeboxScreen = f.current as JukeboxScreen
	assert_true(s != null, "jukebox screen")
	assert_eq(s.director, cabinet, "QC-48: previews go through the cabinet")
	assert_false(s.find_child("PreviewDirector", true, false) != null, "no bare director instanced")
	assert_true(s.play(&"glasshouse"))
	assert_eq(cabinet.get(&"calls"), ["preview:glasshouse:stealth"] as Array[String])
	s.back_button.pressed.emit()
	await wait_frames(2)
	assert_eq((cabinet.get(&"calls") as Array[String]).back(), "stop", "leaving stops the preview")
	assert_eq((sh.map as MockSafehouseMap).jukebox_tracks.back(), &"glasshouse", "the saved pick plays again")
	assert_true(is_instance_valid(cabinet), "the screen never frees the cabinet")
	await _done(f)
	# 2D hub: the screen keeps its own bare director.
	var g: MenuFlow = _flow("res://tests/b/mock_safehouse/missing.tscn")
	await _enter(g)
	assert_true(g.open_station(&"jukebox"))
	await wait_frames(2)
	var s2: JukeboxScreen = g.current as JukeboxScreen
	assert_true(s2.preview_target == null)
	if JukeboxScreen.preview_available():
		assert_true(s2.director != null and s2.director.get_parent() == s2, "bare MusicDirector child")
	await _done(g)


func test_range_frees_the_safehouse_and_returns_at_return_range() -> void:
	var f: MenuFlow = _flow()
	await _enter(f)
	_station(f, &"range").call(&"use")
	await wait_frames(3)
	assert_true(f.firing_range != null and f.firing_range.is_inside_tree(), "range entered")
	assert_false(f.safehouse.is_active(), "range frees the safehouse")
	f.firing_range.exit_requested.emit()
	await wait_frames(2)
	assert_true(f.safehouse.is_active(), "back in the safehouse")
	assert_eq(f.current, f.safehouse.hud as Control)
	assert_true(_walker(f).global_position.is_equal_approx(_marker(f, "Spawns/ReturnRange")), "at ReturnRange")
	assert_false(bool(_walker(f).get(&"paused")))
	# Heist launch frees it with ReturnHeist as the next entry.
	f.safehouse.leave(f.safehouse.tweak.heist_marker)
	assert_eq(f.safehouse.return_marker, &"ReturnHeist")
	f.show_home()
	await wait_frames(1)
	assert_true(_walker(f).global_position.is_equal_approx(_marker(f, "Spawns/ReturnHeist")), "home after a heist")
	await _done(f)


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## ENV A's real hub crew (A3-11, CrewController.spawn_for_hub): spawned at ReturnHeist, PlayerInput paused
## behind a station screen and resumed on Back, back at the station's UsePoint (horizontal, CREW_TOL_M).
func test_real_hub_crew() -> void:
	var cls: Script = UiNav.global_class(&"CrewController")
	var has_hook: bool = false
	if cls != null:
		for m: Dictionary in cls.get_script_method_list():
			has_hook = has_hook or StringName(m["name"]) == &"spawn_for_hub"
	if not has_hook:
		skip("ENV A's CrewController.spawn_for_hub (A3-11) is not on this tree")
		return
	var f: MenuFlow = _flow(MOCK_SCENE, 0.0, MOCK_CLASS, true)
	await _enter(f)
	var sh: SafehouseHost = f.safehouse
	assert_true(sh.is_active(), "3D safehouse with the real crew")
	var crew: Node3D = _walker(f)
	assert_true(crew is CharacterBody3D and crew.get_script() == cls, "A's CrewController, not the stand-in")
	assert_true(_flat(crew.global_position).distance_to(_flat(_marker(f, "Spawns/ReturnHeist"))) < CREW_TOL_M,
			"spawned at ReturnHeist")
	var pin: Node = crew.get_node_or_null(^"PlayerInput")
	assert_true(pin != null and bool(pin.get(&"enabled")), "PlayerInput live while walking")
	assert_true(crew.find_children("*", "Camera3D", true, false).size() >= 1, "the crew's own camera")
	_station(f, &"armory").call(&"use")
	await wait_frames(2)
	assert_eq(f.current, f.loadout_screen as Control, "armory screen opened")
	assert_false(bool(pin.get(&"enabled")), "set_input_paused(true) behind the screen")
	f.loadout_screen.back_button.pressed.emit()
	await wait_physics_frames(3)
	assert_true(bool(pin.get(&"enabled")), "input resumed")
	assert_true(_flat(crew.global_position).distance_to(_flat(_marker(f, "Stations/armory/UsePoint"))) < CREW_TOL_M,
			"back at the armory UsePoint")
	await _done(f)
