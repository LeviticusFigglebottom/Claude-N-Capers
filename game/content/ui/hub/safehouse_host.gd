## 3D safehouse hub mode for MenuFlow (B6-06; QC-45..49, docs/design/heists/safehouse.md). Owner: ENV B.
## A child node of MenuFlow (`MenuFlow.safehouse`), split out to keep MenuFlow's API small.
##
## show_home(profile) is MenuFlow.show_hub()'s 3D branch. It instances ENV C's safehouse scene from data
## (SafehouseHubTweak.scene_path; the root must be `map_class`, looked up by name), spawns the LOCAL
## player's walker (ENV A's `CrewController.spawn_for_hub(map, xform, loadout)`, QC-43; else a walker
## stand-in in `walker_group` inside the scene) at the return marker, connects every station signal to
## the station flow, and shows the hub HUD (crosshair dot + interaction prompt). It returns false, and
## MenuFlow shows the 2D HubMenu, when the player picked "menu" in Options, or the scene, its class or
## any walker is missing. The hub is local per player: only our own walker is paused or moved.
##
## Stations: the root's and every station node's `station_requested(id)` (or A's `station_used(id, crew)`)
## -> the walker's input is paused, the mouse released and the 3D view dimmed; with a `StationCam` child (a
## Marker3D: -Z = view direction, meta `fov` in degrees, default 60) the walker's OWN camera blends to its
## transform and FOV over station_cam_blend_s first; then MenuFlow.open_station(id). Every station's Back
## lands in MenuFlow.show_hub() -> show_home(): the walker returns to that station's UsePoint, its camera
## transform / FOV are restored, input and mouse come back, and the jukebox plays the saved pick
## (`set_jukebox_track`). While a station screen other than the jukebox is open the cabinet is ducked
## (MusicDirector.set_ducked, when it exists). Esc / `pause` on the HUD opens SafehousePauseMenu (Resume,
## quick stations, Options, Achievements, Main Menu).
## The range and a heist launch free the scene (leave(marker)); coming home re-instances it at
## ReturnRange / ReturnHeist; an unknown return id falls back to the `Spawn` marker (hub_map.md v1.0).
class_name SafehouseHost
extends Node

## True once the missing-scene note was logged (once per session).
static var _missing_logged: bool = false
## Tests that drive the 2D HubMenu set this (BTestUtil.pin_menu_hub) so ENV C's scene at the contract path and the
## walk-by-default setting never route them into the 3D hub. Never set by the game.
static var menu_hub_only: bool = false

var flow: MenuFlow
var tweak: SafehouseHubTweak
## The instanced safehouse scene root (null while the 2D hub is used).
var map: Node = null
## The local player's walker (A's hub crew member, or the scene's stand-in).
var walker: Node = null
## Hub HUD (crosshair + prompt) and pause menu: MenuFlow screens.
var hud: SafehouseHud
var pause_menu: SafehousePauseMenu
## LocalHudModel tracking the walker (or the stand-in itself when it has `interaction_changed`).
var hud_model: Node = null
## Station whose screen was opened from the world (&"" = walking, pause menu or a quick station).
var station_id: StringName = &""
## True while the walker's input is paused (station screen / pause menu).
var input_paused: bool = false
## True while the mouse is free for the UI (MouseCapture &"station" release held, input_focus.md 1.1).
var mouse_released: bool = true
## Marker the next enter() spawns at (set by leave(marker)); &"" = tweak.entry_marker.
var return_marker: StringName = &""
## True while the cabinet is ducked under a station screen.
var ducked: bool = false
var _walker_cam: Camera3D = null
## The walker camera's local transform and FOV before a StationCam blend ({} = not blended).
var _cam_home: Dictionary = {}
var _blend_tween: Tween = null


## Creates the hub HUD and pause menu screens under `p_flow` (hidden).
func setup(p_flow: MenuFlow) -> void:
	flow = p_flow
	if tweak == null:
		tweak = SafehouseHubTweak.load_default()
	hud = SafehouseHud.new()
	hud.name = "SafehouseHud"
	hud.visible = false
	flow.add_child(hud)
	hud.back_requested.connect(open_pause)
	pause_menu = SafehousePauseMenu.new()
	pause_menu.name = "SafehousePause"
	pause_menu.stations = flow.stations
	pause_menu.visible = false
	flow.add_child(pause_menu)


## Options -> Controls -> Safehouse: walk around (3D) or the station menu (2D).
func walk_enabled() -> bool:
	return GameSettings.current().hub_walk()


## The safehouse scene exists and its root class is registered.
func scene_available() -> bool:
	if tweak.scene_path == "" or not ResourceLoader.exists(tweak.scene_path):
		return false
	return tweak.map_class == &"" or UiNav.global_class(tweak.map_class) != null


func is_active() -> bool:
	return map != null and is_instance_valid(map)


## MenuFlow.show_hub() in 3D: enters the safehouse if needed, puts the walker back (at the station's
## UsePoint when a station screen was open), resumes it and shows the hub HUD. False = use the 2D hub.
func show_home(p: PlayerProfile) -> bool:
	if menu_hub_only or not walk_enabled():
		leave()
		return false
	if not enter():
		return false
	_resume(p)
	hud.set_profile(p)  # D-115: the START HERE note until the first heist is on the record
	flow.show_screen(hud)
	return true


## Instances the safehouse and spawns the walker at the return marker. False (nothing kept) when the
## scene, its class or a walker is missing.
func enter() -> bool:
	if is_active():
		return true
	if not scene_available():
		if not _missing_logged:  # the expected path until a 3D safehouse exists: say it once per session
			_missing_logged = true
			Log.info(&"ui", "safehouse scene unavailable (%s); 2D hub" % tweak.scene_path)
		return false
	var ps: PackedScene = load(tweak.scene_path) as PackedScene
	var root: Node = ps.instantiate() if ps != null else null
	if root == null or not _is_map(root):
		Log.warn(&"ui", "safehouse scene root is not a %s; 2D hub" % tweak.map_class)
		if root != null:
			root.free()
		return false
	map = root
	add_child(map)
	# A's ProbeWarmup (r290): render the safehouse's UPDATE_ONCE reflection probes once, in its own SubViewport,
	# so metals don't read dark the first time they come into view. Fire-and-forget: enter() stays synchronous.
	if ProbeWarmup.wanted({}) and map is Node3D:
		ProbeWarmup.warm(map as Node3D)
	var marker: StringName = return_marker if return_marker != &"" else tweak.entry_marker
	return_marker = &""
	walker = _spawn_walker(spawn_transform(marker))
	if walker == null:
		Log.info(&"ui", "no hub crew (%s.%s) and no walker stand-in; 2D hub" % [tweak.crew_class, tweak.spawn_method])
		leave()
		return false
	_connect_stations()
	_walker_cam = RangeCrewBridge.activate_camera(walker)
	# A stand-in that exposes the HUD-model `interaction` shape itself is read directly; A's crew is
	# followed by a LocalHudModel (ui_hud.md `track(crew)`, QC-43 adds the focused prompt to it).
	if walker.has_signal(&"interaction_changed"):
		hud_model = walker
	else:
		hud_model = RangeCrewBridge.track_hud_model(map, walker)
	hud.bind_model(hud_model)
	return true


## Frees the safehouse (range, heist launch, main menu, "menu" mode). `marker` = where the next enter()
## spawns (tweak.range_marker / heist_marker); ignored while the 2D hub is in use.
func leave(marker: StringName = &"") -> void:
	if not is_active():
		return
	if marker != &"":
		return_marker = marker
	hud.bind_model(null)
	_set_ducked(false)
	_restore_camera()
	remove_child(map)
	map.queue_free()
	map = null
	walker = null
	hud_model = null
	_walker_cam = null
	station_id = &""
	input_paused = false
	_set_backdrop(false, false)
	# PO-21 (P's root cause): the 2D MenuFlow keeps eating clicks, but the station release must not outlive the
	# safehouse: a held &"station" release kept every heist / range launched from here on a free cursor (no mouse look).
	mouse_released = true
	flow.mouse_filter = Control.MOUSE_FILTER_STOP
	MouseCapture.pop_release(&"station")


## The root's `spawn_transform(id)` (which falls back to `Spawn` itself, hub_map.md), else marker_transform().
func spawn_transform(marker: StringName) -> Transform3D:
	if not is_active():
		return Transform3D.IDENTITY
	if map.has_method(&"spawn_transform"):
		return map.call(&"spawn_transform", marker) as Transform3D
	return marker_transform(map, marker, tweak.spawn_marker)


## A Node3D named `marker` under `root`, else the one named `fallback` (the `Spawn` loading bay marker, so a
## missing return point never strands the player), else identity.
static func marker_transform(root: Node, marker: StringName, fallback: StringName) -> Transform3D:
	for id: StringName in [marker, fallback]:
		var n: Node3D = root.find_child(String(id), true, false) as Node3D if id != &"" else null
		if n != null:
			return n.global_transform
	return Transform3D.IDENTITY


## Station nodes: members of G.HUB_STATION inside the scene plus the children of `Stations/`.
func stations() -> Array[Node]:
	var out: Array[Node] = []
	if not is_active():
		return out
	for n: Node in get_tree().get_nodes_in_group(G.HUB_STATION):
		if map.is_ancestor_of(n):
			out.append(n)
	var holder: Node = map.get_node_or_null(NodePath(tweak.stations_node))
	if holder != null:
		for n: Node in holder.get_children():
			if not out.has(n):
				out.append(n)
	return out


## The station node of `id` (its `station_id`, else its name), or null.
func station_node(id: StringName) -> Node:
	for n: Node in stations():
		if _station_id_of(n) == id:
			return n
	return null


## QC-48: the cabinet the JukeboxScreen previews through (the root's `jukebox`, else a `Jukebox` node
## with preview()), or null (2D hub: the screen uses its own bare MusicDirector).
func jukebox() -> Node:
	if not is_active():
		return null
	var j: Variant = map.get(tweak.jukebox_property)
	if j is Node and (j as Node).has_method(JukeboxScreen.PREVIEW_METHOD):
		return j as Node
	var n: Node = map.find_child(tweak.jukebox_node, true, false)
	return n if n != null and n.has_method(JukeboxScreen.PREVIEW_METHOD) else null


## MenuFlow.open_station(id): duck the cabinet under every station screen but the jukebox's own (hub_map.md).
func station_opened(id: StringName) -> void:
	_set_ducked(is_active() and id != tweak.jukebox_station)


## QC-49: the pause menu over the dimmed safehouse (walker paused, mouse free).
func open_pause() -> void:
	if not is_active():
		return
	_pause_walker(true)
	_set_backdrop(true, true)
	flow.show_screen(pause_menu)


func _is_map(root: Node) -> bool:
	if tweak.map_class == &"":
		return true
	var want: Script = UiNav.global_class(tweak.map_class)
	var s: Script = root.get_script() as Script
	while s != null:
		if s == want:
			return true
		s = s.get_base_script()
	return false


func _spawn_walker(xform: Transform3D) -> Node:
	var cls: Script = UiNav.global_class(tweak.crew_class)
	if cls != null and _has_method(cls, tweak.spawn_method):
		var p: PlayerProfile = flow.profile if flow.profile != null else SaveService.load_profile(flow.profile_slot)
		var crew: Node = cls.call(tweak.spawn_method, map, xform, LoadoutResolver.resolve(p.loadout)) as Node
		if crew != null:
			return crew
	for n: Node in get_tree().get_nodes_in_group(tweak.walker_group):
		if map.is_ancestor_of(n):
			_teleport(n, xform)
			return n
	return null


func _connect_stations() -> void:
	var sources: Array[Node] = [map]
	sources.append_array(stations())
	for src: Node in sources:
		for sig: StringName in tweak.station_signals:
			if not src.has_signal(sig):
				continue
			var extra: int = maxi(_arg_count(src, sig) - 1, 0)
			var cb: Callable = _on_station_requested.unbind(extra) if extra > 0 else _on_station_requested
			src.connect(sig, cb)


## A station used in the world: pause, dim, optional camera blend, then the station's screen.
## Ignored unless walking (a second signal for the same use, e.g. station + root, is dropped).
func _on_station_requested(id: StringName) -> void:
	if not is_active() or station_id != &"" or flow.current != hud:
		return
	station_id = id
	_pause_walker(true)
	_set_backdrop(true, true)
	var st: Node = station_node(id)
	var cam: Node3D = st.get_node_or_null(NodePath(tweak.station_cam_name)) as Node3D if st != null else null
	if cam != null and tweak.station_cam_blend_s > 0.0:
		await _blend_to(cam)
		if not is_active() or station_id != id:
			return
	if not flow.open_station(id):
		flow.show_hub()


## Blends the walker's own camera to the StationCam marker's transform and FOV (meta, default station_cam_fov).
## No walker camera: nothing to blend.
func _blend_to(target: Node3D) -> void:
	var cam: Camera3D = _walker_cam
	if cam == null or not is_instance_valid(cam):
		return
	if _cam_home.is_empty():
		_cam_home = {"transform": cam.transform, "fov": cam.fov}
	var fov: float = float(target.get_meta(tweak.station_cam_fov_meta, tweak.station_cam_fov))
	var s: float = tweak.station_cam_blend_s
	_blend_tween = cam.create_tween().set_parallel(true)
	_blend_tween.tween_property(cam, ^"global_transform", target.global_transform, s)
	_blend_tween.tween_property(cam, ^"fov", fov, s)
	await _blend_tween.finished


## Puts the walker camera back (local transform + FOV from before the blend) and makes it current. A blend
## still running is fast-forwarded first, so its awaiting caller wakes up and sees the station was left.
func _restore_camera() -> void:
	if _blend_tween != null and _blend_tween.is_valid():
		_blend_tween.custom_step(tweak.station_cam_blend_s + 1.0)
		_blend_tween.kill()
	_blend_tween = null
	if _walker_cam != null and is_instance_valid(_walker_cam):
		if not _cam_home.is_empty():
			_walker_cam.transform = _cam_home["transform"] as Transform3D
			_walker_cam.fov = float(_cam_home["fov"])
		_walker_cam.current = true
	_cam_home = {}


func _set_ducked(on: bool) -> void:
	if on == ducked:
		return
	ducked = on
	var j: Node = jukebox()
	if j != null and j.has_method(tweak.duck_method):
		j.call(tweak.duck_method, on)


func _resume(p: PlayerProfile) -> void:
	var st: Node = station_node(station_id) if station_id != &"" else null
	var use_point: Node3D = st.get_node_or_null(NodePath(tweak.use_point_name)) as Node3D if st != null else null
	if use_point != null:
		_teleport(walker, use_point.global_transform)
	_restore_camera()
	_set_ducked(false)
	station_id = &""
	_pause_walker(false)
	_set_backdrop(false, true)
	if p != null and map.has_method(tweak.jukebox_track_method):
		map.call(tweak.jukebox_track_method, MusicCatalog.resolve_choice(p))


func _pause_walker(paused: bool) -> void:
	input_paused = paused
	if walker != null and is_instance_valid(walker) and walker.has_method(&"set_input_paused"):
		walker.call(&"set_input_paused", paused)
	_release_mouse(paused)


## The MenuFlow Control must not eat mouse look while walking.
func _release_mouse(released: bool) -> void:
	mouse_released = released
	flow.mouse_filter = Control.MOUSE_FILTER_STOP if released else Control.MOUSE_FILTER_IGNORE
	# input_focus.md 1.1: the walker's PlayerInput owns gameplay capture; a station / pause holds the cursor.
	if released:
		MouseCapture.push_release(&"station")
	else:
		MouseCapture.pop_release(&"station")


## MenuFlow's backdrop: opaque in the 2D menus; over the 3D view hidden while walking, dimmed behind screens.
func _set_backdrop(dim: bool, over_3d: bool) -> void:
	var bg: ColorRect = flow.background
	if bg == null:
		return
	if not over_3d:
		bg.color = UiAccent.app_bg()
		bg.visible = true
		return
	bg.color = Color(UiAccent.app_bg(), tweak.dim_alpha)
	bg.visible = dim


static func _teleport(n: Node, xform: Transform3D) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n.has_method(&"teleport"):
		n.call(&"teleport", xform)
	elif n is Node3D:
		(n as Node3D).global_transform = xform


static func _station_id_of(n: Node) -> StringName:
	var v: Variant = n.get(&"station_id")
	return StringName(v) if v != null and StringName(v) != &"" else StringName(n.name)


static func _has_method(script: Script, method: StringName) -> bool:
	for m: Dictionary in script.get_script_method_list():
		if StringName(m["name"]) == method:
			return true
	return false


static func _arg_count(obj: Object, signal_name: StringName) -> int:
	for sig: Dictionary in obj.get_signal_list():
		if StringName(sig["name"]) == signal_name:
			return (sig["args"] as Array).size()
	return 0
