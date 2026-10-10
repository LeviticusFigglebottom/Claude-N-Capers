## Base of every map-placed gameplay prefab. Owner: ENV A.
## Contracts: gameplay_prefabs.md "Common shape", visual_slots.md (named nodes), architecture.md §6.
## Shape: root (this script) -> `Visual` (art from `visual_scene`, else the placeholder, instanced at
## runtime), `UsePoint` (Marker3D, interactive prefabs), `Interactable` (InteractableComponent).
## Interactive subclasses declare the common interaction exports themselves (interaction_time_s,
## requires_item, stealth_only, loud_only, casing_allowed, noise); `_ready` copies them into
## `Interactable`. `interaction_time_s < 0` means "use the InteractionTweak default".
## Subclasses override the virtual hooks below, never `_ready`.
class_name GameplayPrefab
extends Node3D

const LOG_CHANNEL: StringName = &"prefab"
## Collision layer bits (project.godot layer_names).
const LAYER_WORLD_STATIC: int = 1 << 0
const LAYER_WORLD_DYNAMIC: int = 1 << 1
const LAYER_PLAYERS: int = 1 << 2
const LAYER_HITBOXES: int = 1 << 4
const LAYER_TRIGGERS: int = 1 << 9

## Art scene (visual_slots.md). Null = placeholder.
@export var visual_scene: PackedScene
## Lets mission scripts find this prefab (HeistRuntime.find_by_tag).
@export var objective_tag: StringName = &""

var net_id: int = 0
## The instanced art or placeholder under `Visual`.
var visual_instance: Node3D = null
var using_placeholder: bool = false

@onready var visual_root: Node3D = get_node_or_null(^"Visual") as Node3D
@onready var use_point: Marker3D = get_node_or_null(^"UsePoint") as Marker3D
@onready var interactable: InteractableComponent = get_node_or_null(^"Interactable") as InteractableComponent


func _ready() -> void:
	NetIds.claim(self)
	_build_visual()
	_check_visual_nodes()
	if &"interaction_time_s" in self and interactable == null:
		Log.error(LOG_CHANNEL, "%s: contract violation: interactive prefab without `Interactable`" % name)
		return
	_apply_common_interaction()
	_prefab_ready()


# --- Virtual hooks -----------------------------------------------------------------

## Placeholder visual used when `visual_scene` is null (never saved inside the prefab scene).
func _placeholder_scene() -> PackedScene:
	return null


## Named nodes the visual scene must provide (visual_slots.md).
func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray()


## Hold time used when `interaction_time_s` is left at the -1 sentinel (InteractionTweak).
func _default_interaction_time() -> float:
	return 0.0


## Subclass setup after the visual exists and the Interactable is configured.
func _prefab_ready() -> void:
	pass


# --- Helpers -----------------------------------------------------------------------

## Named node inside the visual (art or placeholder), or null.
func visual_node(node_name: String) -> Node:
	if visual_root == null:
		return null
	return visual_root.find_child(node_name, true, false)


## True when this prefab declares the interaction exports (interactive prefab).
func is_interactive() -> bool:
	return interactable != null


func _build_visual() -> void:
	if visual_root == null:
		Log.error(LOG_CHANNEL, "%s: contract violation: missing `Visual` node" % name)
		return
	var scene: PackedScene = visual_scene
	using_placeholder = scene == null
	if scene == null:
		scene = _placeholder_scene()
	if scene == null:
		return
	var inst: Node = scene.instantiate()
	visual_instance = inst as Node3D
	if visual_instance == null:
		Log.error(LOG_CHANNEL, "%s: visual scene root must be a Node3D" % name)
		inst.free()
		return
	visual_root.add_child(visual_instance)


func _check_visual_nodes() -> void:
	for n: String in required_visual_nodes():
		if visual_node(n) == null:
			Log.error(LOG_CHANNEL, "%s: visual scene is missing required node `%s` (visual_slots.md)" % [name, n])


func _apply_common_interaction() -> void:
	if interactable == null:
		return
	var t: float = float(get(&"interaction_time_s"))
	interactable.interaction_time_s = _default_interaction_time() if t < 0.0 else t
	interactable.requires_item = StringName(get(&"requires_item"))
	interactable.stealth_only = bool(get(&"stealth_only"))
	interactable.loud_only = bool(get(&"loud_only"))
	interactable.casing_allowed = bool(get(&"casing_allowed"))
	interactable.noise = StringName(get(&"noise"))


## Emit an EventBus fact on the server and relay it to clients (architecture.md §5).
func _emit_fact(sig: StringName, args: Array) -> void:
	EventBus.emit_signal.callv([sig] + args)
	Net.replicate_event(sig, args)


## Ask the audio player for a cue (audio_cues.md) on the server and relay it.
func _cue(cue_id: StringName, pos: Vector3) -> void:
	_emit_fact(&"audio_cue_requested", [cue_id, pos, net_id])


## The stealth director of the running heist, or null (standalone prefab).
func _stealth() -> StealthDirector:
	return HeistRuntime.get_service(G.SVC_STEALTH) as StealthDirector


## Server: raise the alarm through the stealth director (no-op without a heist).
func _raise_alarm(reason: StringName, source_net_id: int) -> void:
	var st: StealthDirector = _stealth()
	if st != null:
		st.raise_alarm(reason, source_net_id)


## Shared glass shatter (S9.9): glass_broken [R], cue, 15 m noise, `broken_glass` stimulus.
## Returns the stimulus id (0 without a heist).
func _shatter_glass(pos: Vector3) -> int:
	_emit_fact(&"glass_broken", [net_id, pos])
	_cue(&"cue.glass_break", pos)
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt != null:
		rt.make_noise(pos, Tweak.stealth().glass_break_radius_m, &"glass", net_id)
	var st: StealthDirector = _stealth()
	if st == null:
		return 0
	return st.register_stimulus(null, &"broken_glass", {"position": pos})


## Point a collision body's hits at this prefab (combat resolves `hit_owner` -> apply_damage).
func _route_hits(body: Node) -> void:
	if body != null:
		body.set_meta(&"hit_owner", self)
