## Entry point to start a heist (test_hooks.md). Owner: ENV A.
## `await HeistLauncher.launch(&"glasshouse", 1001, Enums.Difficulty.ROUTINE, self)`
## Co-op (A3-07): the host's launch() sends the bring-up to every client through
## `Net.lobby_send(BRING_UP_KIND, ...)`; a client `await`s `launch_client()` (the counterpart of
## launch(): returns the replica once the host's bring-up arrived), builds it by hand with
## `join_running(data)`, or calls `auto_join()` once in the lobby (heist/README.md "Co-op").
class_name HeistLauncher
extends RefCounted

## Net.lobby_message kind carrying HeistNetSync.bring_up() (server -> clients).
const BRING_UP_KIND: StringName = &"heist_bring_up"
const BRING_UP_VERSION: int = 1
## X-5: launch() waits at most this many physics frames for the heist's navmesh to sync (_await_navigation).
const NAV_READY_MAX_FRAMES: int = 600

## Maps owned by ENV A (dev only, never shipped as heists).
const BUILTIN_MAPS: Dictionary = {
	&"dev_sandbox": "res://systems/dev/dev_sandbox.tscn",
}

## D-133: the harness-only dev option keys (see dev_options).
const DEV_KEYS: Array[String] = ["crew_damage_taken_mult"]

static var _registry: Dictionary = {}
## TEST HOOK (PO-5 release e2e): the next launch() uses this run seed instead of the caller's (the menu
## picks a time seed), then it resets to -1. Lets a windowed menu-driven playthrough be replayed exactly.
static var next_seed_override: int = -1
## D-133 HARNESS-ONLY dev options (the e2e runners set them before boot; no menu, profile or save writes them). Only
## DEV_KEYS are honoured, and only from here: launch() strips the same keys from the caller's options (menus build
## those), then merges these over them. Printed in the heist log header.
static var dev_options: Dictionary = {}
static var _auto_join: Dictionary = {}
## launch_client() calls waiting for a bring-up (auto_join stands aside while > 0).
static var _client_pending: int = 0
## Bumped by cancel_launch_client(): every pending launch_client() returns null.
static var _client_gen: int = 0


## D-133: `options` without any caller-supplied DEV_KEYS, plus the harness's dev_options.
static func with_dev_options(options: Dictionary) -> Dictionary:
	var out: Dictionary = options.duplicate()
	for k: String in DEV_KEYS:
		out.erase(k)
	for k: Variant in dev_options:
		if DEV_KEYS.has(String(k)):
			out[String(k)] = dev_options[k]
	return out


## Register an id -> map scene path (used until the lead publishes a heist catalog, QA-1).
static func register_map(heist_id: StringName, scene_path: String) -> void:
	_registry[heist_id] = scene_path


## Path of a heist's map scene. Order: options.map_scene, registry, ENV A built-ins,
## then core `HeistRegistry.map_scene_path` (D-025, QA-1).
static func map_path(heist_id: StringName, options: Dictionary = {}) -> String:
	if options.has("map_scene"):
		return String(options["map_scene"])
	if _registry.has(heist_id):
		return String(_registry[heist_id])
	if BUILTIN_MAPS.has(heist_id):
		return String(BUILTIN_MAPS[heist_id])
	return HeistRegistry.map_scene_path(heist_id)


## Load a heist into `parent` (or the scene tree root), solo session unless a session is live.
## Returns the HeistRuntime once variants are resolved and NPCs + crew are spawned (or null).
## options: { "ai_teammates": int (3), "loadouts": {slot: Loadout}, "skip_casing": bool,
##            "difficulty_def": DifficultyDef, "map_scene": String, "map_packed": PackedScene, "extra_services": [Callable] }
static func launch(heist_id: StringName, seed: int, difficulty: Enums.Difficulty,
		parent: Node = null, options: Dictionary = {}) -> HeistRuntime:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if next_seed_override >= 0:
		seed = next_seed_override
		next_seed_override = -1
	if parent == null:
		parent = tree.root
	options = with_dev_options(options)
	var scene: PackedScene = options.get("map_packed") as PackedScene
	if scene == null:
		var path: String = map_path(heist_id, options)
		if path == "" or not ResourceLoader.exists(path):
			Log.error(&"heist", "unknown heist '%s' (map path '%s')" % [heist_id, path])
			return null
		scene = await _load_map(path)
	var live_session: bool = tree.root.multiplayer.has_multiplayer_peer() \
		and not (tree.root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and not Net.crew.is_empty()
	if live_session:
		if not Net.is_authority():
			Log.error(&"heist", "launch() is server-only")
			return null
		var old: HeistRuntime = HeistRuntime.current()
		if old != null:  # C11: a co-op heist left up would hold the node path the new heist's RPCs need
			Log.warn(&"heist", "launch(): tearing down the previous heist %s first" % old.heist_id)
			old.teardown()
		Net.fill_with_ai()
	else:
		Net.start_solo("Player", int(options.get("ai_teammates", 3)))
	Ids.reset()
	Services.clear()
	var rt: HeistRuntime = HeistRuntime.new()
	rt.name = "HeistRuntime"
	parent.add_child(rt)
	if not rt.start(heist_id, scene, seed, difficulty, options):
		rt.teardown()
		return null
	if live_session:  # A3-07: before any physics frame, so no RPC reaches a client without a replica
		Net.lobby_send(BRING_UP_KIND, rt.net_sync.bring_up())
	await tree.physics_frame
	await tree.physics_frame
	await _await_navigation(rt)
	if ProbeWarmup.wanted(options) and is_instance_valid(rt) and rt.map != null:
		await ProbeWarmup.warm(rt.map)  # LEAD r287: no dark metals on a probe's first view
	return rt


## X-5: navigation regions (and the map) sync on worker threads (Godot's async iterations), so a fresh map's
## navmesh is not queryable for a few physics frames, more under CPU load: map_get_closest_point answered the
## origin and the GH "police do not park under the crew upstairs" test teleported the crew to the spawn instead
## (~1 run in 30 in the police batch). Wait until every enabled region of the heist has built and
## the map answers queries from it, at most NAV_READY_MAX_FRAMES physics frames (then warn and go on).
static func _await_navigation(rt: HeistRuntime) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var frames: int = 0
	while not navigation_ready(rt):
		if frames >= NAV_READY_MAX_FRAMES or not is_instance_valid(rt) or not rt.is_inside_tree():
			if is_instance_valid(rt) and rt.is_inside_tree():
				Log.warn(&"heist", "launch(): navigation not synced after %d physics frames" % frames)
			return
		await tree.physics_frame
		frames += 1
	if frames > 0:
		Log.info(&"heist", "launch(): navigation synced after %d more physics frames" % frames)


## True when every enabled NavigationRegion3D (with polygons) under `rt` has built and its map's current iteration
## includes it: the map has a polygon (of some region) right on a point of the region's own surface.
static func navigation_ready(rt: HeistRuntime) -> bool:
	if rt == null or not is_instance_valid(rt) or not rt.is_inside_tree():
		return true
	for n: Node in rt.find_children("*", "NavigationRegion3D", true, false):
		var reg: NavigationRegion3D = n as NavigationRegion3D
		if not reg.is_inside_tree() or not reg.enabled or reg.navigation_mesh == null \
				or reg.navigation_mesh.get_polygon_count() == 0:
			continue
		var rid: RID = reg.get_rid()
		var map_rid: RID = reg.get_navigation_map()
		if not map_rid.is_valid() or NavigationServer3D.region_get_iteration_id(rid) == 0 \
				or NavigationServer3D.map_get_iteration_id(map_rid) == 0:
			return false
		var centre: Vector3 = NavigationServer3D.region_get_bounds(rid).get_center()
		var p: Vector3 = NavigationServer3D.region_get_closest_point(rid, centre)
		if not NavigationServer3D.map_get_closest_point_owner(map_rid, p).is_valid() \
				or NavigationServer3D.map_get_closest_point(map_rid, p).distance_to(p) > 0.05:
			return false
	return true


## The map scene, loaded on a worker thread while the main loop keeps running (one frame per poll),
## so ENet stays serviced and co-op clients do not time out during a slow host bring-up (ENV B co-op
## finding). An already cached map returns at once.
static func _load_map(path: String) -> PackedScene:
	if ResourceLoader.has_cached(path):
		return load(path) as PackedScene
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if ResourceLoader.load_threaded_request(path, "PackedScene", true) != OK:
		return load(path) as PackedScene
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await tree.process_frame
	return ResourceLoader.load_threaded_get(path) as PackedScene


## Client (A3-07): build the replica of the host's running heist from its bring-up data
## (`HeistNetSync.bring_up()`, received as Net.lobby_message kind BRING_UP_KIND from peer 1).
## Synchronous, so the replication RPCs right behind the bring-up find their nodes. `parent` null =
## the node at the host's runtime parent path (RPC paths must match), else the tree root.
## options: { "map_packed": PackedScene, "map_scene": String, "extra_services": [Callable] }.
static func join_running(data: Dictionary, parent: Node = null, options: Dictionary = {}) -> HeistRuntime:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if Net.is_authority():
		Log.error(&"heist", "join_running() is client-only")
		return null
	if int(data.get("version", 0)) != BRING_UP_VERSION:
		Log.error(&"heist", "bring-up version %s, expected %d" % [data.get("version"), BRING_UP_VERSION])
		return null
	var heist_id: StringName = StringName(data.get("heist_id", &""))
	var host_path: String = String(data.get("runtime_path", ""))
	if parent == null:
		var parent_path: String = host_path.substr(0, host_path.rfind("/")) if host_path.rfind("/") > 0 else "/root"
		parent = tree.root.get_node_or_null(NodePath(parent_path))
		if parent == null:
			parent = tree.root
	var scene: PackedScene = options.get("map_packed") as PackedScene
	if scene == null:
		var path: String = String(data.get("map_scene", ""))
		if options.has("map_scene") or path == "" or not ResourceLoader.exists(path):
			path = map_path(heist_id, options)
		if path == "" or not ResourceLoader.exists(path):
			Log.error(&"heist", "replica: unknown heist '%s' (map path '%s')" % [heist_id, path])
			return null
		scene = load(path) as PackedScene
	var old: HeistRuntime = HeistRuntime.current()
	if old != null:
		old.teardown()
	Ids.reset()
	Services.clear()
	var rt: HeistRuntime = HeistRuntime.new()
	rt.name = "HeistRuntime"
	parent.add_child(rt)
	if host_path != "" and String(rt.get_path()) != host_path:
		Log.error(&"net", "replica runtime at %s but the host's is at %s: RPCs will not route" % [rt.get_path(), host_path])
	var opts: Dictionary = options.duplicate()
	opts["bring_up"] = data
	if not rt.start(heist_id, scene, int(data.get("seed", 0)), int(data.get("difficulty", 0)), opts):
		rt.teardown()
		return null
	return rt


## Client (A3-07, B's lobby): the client-side counterpart of launch(). Waits for the host's next
## bring-up (Net.lobby_message kind BRING_UP_KIND from peer 1), builds the replica with
## join_running(data, parent, options) INSIDE the message handler (so the replication RPCs right
## behind it find their nodes), then awaits two physics frames like launch() and returns the replica
## HeistRuntime (`rt.is_replica == true`). Call it before the host calls launch() (at the latest on the
## lobby's own "starting" message: lobby messages are reliable and ordered, so the bring-up comes after).
## `timeout_s` <= 0 waits until the bring-up, a host loss or cancel_launch_client().
## Returns null: on the authority (host / solo: use launch()), when the bring-up is rejected
## (version mismatch, unknown map: Log.error), on timeout, when the connection to the host is lost
## (`multiplayer.server_disconnected`) or the session ends (`Net.leave()` -> Net.session_ended), and
## when cancel_launch_client() is called. While it waits, auto_join() does not also build a replica.
## Also returns null on Net.connection_failed / Net.host_lost (D-052).
static func launch_client(parent: Node = null, options: Dictionary = {}, timeout_s: float = 0.0) -> HeistRuntime:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if Net.is_authority():
		Log.error(&"heist", "launch_client() is client-only (the host calls launch())")
		return null
	var state: Dictionary = {"done": false, "rt": null}
	var on_msg: Callable = func(from_peer: int, kind: StringName, data: Dictionary) -> void:
		if bool(state["done"]) or kind != BRING_UP_KIND or from_peer != 1 or not for_me(data):
			return
		state["done"] = true
		state["rt"] = join_running(data, parent if is_instance_valid(parent) else null, options)
	var on_lost: Callable = func() -> void:
		state["done"] = true
	var mp: MultiplayerAPI = tree.root.multiplayer
	Net.lobby_message.connect(on_msg)
	Net.session_ended.connect(on_lost)
	Net.connection_failed.connect(on_lost)
	Net.host_lost.connect(on_lost)
	mp.server_disconnected.connect(on_lost)
	_client_pending += 1
	var gen: int = _client_gen
	var deadline_ms: int = Time.get_ticks_msec() + int(timeout_s * 1000.0) if timeout_s > 0.0 else -1
	while not bool(state["done"]) and gen == _client_gen:
		if deadline_ms >= 0 and Time.get_ticks_msec() > deadline_ms:
			Log.warn(&"heist", "launch_client(): no bring-up from the host within %.1f s" % timeout_s)
			break
		await tree.process_frame
	_client_pending -= 1
	Net.lobby_message.disconnect(on_msg)
	Net.session_ended.disconnect(on_lost)
	Net.connection_failed.disconnect(on_lost)
	Net.host_lost.disconnect(on_lost)
	if mp.server_disconnected.is_connected(on_lost):
		mp.server_disconnected.disconnect(on_lost)
	var v: Variant = state["rt"]
	if v == null or not is_instance_valid(v):
		return null
	var rt: HeistRuntime = v as HeistRuntime
	await tree.physics_frame
	await tree.physics_frame
	if is_instance_valid(rt) and rt.map != null and ProbeWarmup.wanted(rt.options):
		await ProbeWarmup.warm(rt.map)  # LEAD r287: the replica's probes too (every rendering peer)
	return rt if is_instance_valid(rt) else null


## QB-B6-DROPIN: a drop-in's bring-up names its peer ("for_peer"); everyone else is already in the heist.
static func for_me(data: Dictionary) -> bool:
	return not data.has("for_peer") or int(data["for_peer"]) == Net.local_peer_id()


## Client: every pending launch_client() returns null (lobby left / cancelled by the UI).
static func cancel_launch_client() -> void:
	_client_gen += 1


## Client (A3-07): join every heist the host launches from now on (call once in the lobby).
## `on_joined(rt: HeistRuntime)` runs after each replica is built. stop_auto_join() undoes it.
static func auto_join(parent: Node = null, options: Dictionary = {}, on_joined: Callable = Callable()) -> void:
	_auto_join = {"parent": parent, "options": options, "on_joined": on_joined}
	if not Net.lobby_message.is_connected(_on_lobby_message):
		Net.lobby_message.connect(_on_lobby_message)


static func stop_auto_join() -> void:
	_auto_join = {}
	if Net.lobby_message.is_connected(_on_lobby_message):
		Net.lobby_message.disconnect(_on_lobby_message)


static func _on_lobby_message(from_peer: int, kind: StringName, data: Dictionary) -> void:
	if kind != BRING_UP_KIND or Net.is_authority() or from_peer != 1 or _client_pending > 0 or not for_me(data):
		return
	var parent: Node = _auto_join.get("parent") as Node if is_instance_valid(_auto_join.get("parent")) else null
	var rt: HeistRuntime = join_running(data, parent, _auto_join.get("options", {}) as Dictionary)
	var cb: Callable = _auto_join.get("on_joined", Callable()) as Callable
	if cb.is_valid():
		cb.call(rt)
