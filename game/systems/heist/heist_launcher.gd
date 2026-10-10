## Entry point to start a heist (test_hooks.md). Owner: ENV A.
## `await HeistLauncher.launch(&"glasshouse", 1001, Enums.Difficulty.ROUTINE, self)`
## Co-op (A3-07): the host's launch() sends the bring-up to every client through
## `Net.lobby_send(BRING_UP_KIND, ...)`; a client builds its replica with `join_running(data)`, or
## calls `auto_join()` once in the lobby to do it on arrival (heist/README.md "Co-op").
class_name HeistLauncher
extends RefCounted

## Net.lobby_message kind carrying HeistNetSync.bring_up() (server -> clients).
const BRING_UP_KIND: StringName = &"heist_bring_up"
const BRING_UP_VERSION: int = 1

## Maps owned by ENV A (dev only, never shipped as heists).
const BUILTIN_MAPS: Dictionary = {
	&"dev_sandbox": "res://systems/dev/dev_sandbox.tscn",
}

static var _registry: Dictionary = {}
static var _auto_join: Dictionary = {}


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
	if parent == null:
		parent = tree.root
	var scene: PackedScene = options.get("map_packed") as PackedScene
	if scene == null:
		var path: String = map_path(heist_id, options)
		if path == "" or not ResourceLoader.exists(path):
			Log.error(&"heist", "unknown heist '%s' (map path '%s')" % [heist_id, path])
			return null
		scene = load(path) as PackedScene
	var live_session: bool = tree.root.multiplayer.has_multiplayer_peer() \
		and not (tree.root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and not Net.crew.is_empty()
	if live_session:
		if not Net.is_authority():
			Log.error(&"heist", "launch() is server-only")
			return null
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
	return rt


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
	if kind != BRING_UP_KIND or Net.is_authority() or from_peer != 1:
		return
	var parent: Node = _auto_join.get("parent") as Node if is_instance_valid(_auto_join.get("parent")) else null
	var rt: HeistRuntime = join_running(data, parent, _auto_join.get("options", {}) as Dictionary)
	var cb: Callable = _auto_join.get("on_joined", Callable()) as Callable
	if cb.is_valid():
		cb.call(rt)
