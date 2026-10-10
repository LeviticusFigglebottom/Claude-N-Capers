## Entry point to start a heist (test_hooks.md). Owner: ENV A.
## `await HeistLauncher.launch(&"glasshouse", 1001, Enums.Difficulty.ROUTINE, self)`
class_name HeistLauncher
extends RefCounted

## Maps owned by ENV A (dev only, never shipped as heists).
const BUILTIN_MAPS: Dictionary = {
	&"dev_sandbox": "res://systems/dev/dev_sandbox.tscn",
}

static var _registry: Dictionary = {}


## Register an id -> map scene path (used until the lead publishes a heist catalog, QA-1).
static func register_map(heist_id: StringName, scene_path: String) -> void:
	_registry[heist_id] = scene_path


## Path of a heist's map scene, or "" if unknown.
## Order: options.map_scene, registry, ENV A built-ins, HeistCatalog (contracts, if present).
static func map_path(heist_id: StringName, options: Dictionary = {}) -> String:
	if options.has("map_scene"):
		return String(options["map_scene"])
	if _registry.has(heist_id):
		return String(_registry[heist_id])
	if BUILTIN_MAPS.has(heist_id):
		return String(BUILTIN_MAPS[heist_id])
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c["class"] == &"HeistCatalog":
			var cat: Script = load(c["path"]) as Script
			if cat != null:
				return String(cat.call(&"map_scene_path", heist_id))
	return ""


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
	await tree.physics_frame
	await tree.physics_frame
	return rt
