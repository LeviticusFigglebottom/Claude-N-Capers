## Base of every map-placed gameplay prefab. Owner: ENV A.
## Contracts: gameplay_prefabs.md "Common shape", visual_slots.md (named nodes), architecture.md §6.
## Shape: root (this script) -> `Visual` (art from `visual_scene`, else the placeholder, instanced at
## runtime), `UsePoint` (Marker3D, interactive prefabs), `Interactable` (InteractableComponent).
## Interactive subclasses declare the common interaction exports themselves (interaction_time_s,
## requires_item, stealth_only, loud_only, casing_allowed, noise); `_ready` copies them into
## `Interactable`. `interaction_time_s < 0` means "use the InteractionTweak default".
## Subclasses override the virtual hooks below, never `_ready`.
## Collision fitting (lead item 6): a prefab that declares `collision_size_override: Vector3` (ZERO =
## auto) has its own `Collision/Shape` box sized at ready (see `_fit_collision`): the override if set,
## else the visual's own `Collision` StaticBody3D (visual_slots.md; the prefab's box is then disabled),
## else the merged AABB of the visual's meshes in this prefab's space, kept on the room side of the
## pivot (`_collision_pivot`: floor y >= 0, wall z <= 0, ceiling y <= 0).
class_name GameplayPrefab
extends Node3D

## Pivot rule of the visual (visual_slots.md) used to clip and place the fitted collision box.
enum CollisionPivot { FLOOR, WALL, CEILING }

const LOG_CHANNEL: StringName = &"prefab"
## Collision layer bits (project.godot layer_names).
const LAYER_WORLD_STATIC: int = 1 << 0
const LAYER_WORLD_DYNAMIC: int = 1 << 1
const LAYER_PLAYERS: int = 1 << 2
const LAYER_HITBOXES: int = 1 << 4
const LAYER_TRIGGERS: int = 1 << 9
## Smallest fitted collision extent per axis (m), so flat art still blocks.
const COLLISION_MIN_EXTENT_M: float = 0.05
## Name of the optional collision body inside a visual scene (visual_slots.md).
const VISUAL_COLLISION_NODE: String = "Collision"

## Art scene (visual_slots.md). Null = placeholder.
@export var visual_scene: PackedScene
## Lets mission scripts find this prefab (HeistRuntime.find_by_tag).
@export var objective_tag: StringName = &""

var net_id: int = 0
## The instanced art or placeholder under `Visual`.
var visual_instance: Node3D = null
var using_placeholder: bool = false
## The visual's own `Collision` StaticBody3D when it supplies one (the prefab's box is then off).
var visual_collision: StaticBody3D = null

@onready var visual_root: Node3D = get_node_or_null(^"Visual") as Node3D
@onready var use_point: Marker3D = get_node_or_null(^"UsePoint") as Marker3D
@onready var interactable: InteractableComponent = get_node_or_null(^"Interactable") as InteractableComponent


func _ready() -> void:
	NetIds.claim(self)
	_build_visual()
	_check_visual_nodes()
	_fit_collision()
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


## Pivot rule for the fitted collision box (visual_slots.md). Floor objects by default.
func _collision_pivot() -> CollisionPivot:
	return CollisionPivot.FLOOR


## Visual node whose meshes define the collision box ("" = the whole visual).
func _collision_source_node() -> String:
	return ""


# --- Helpers -----------------------------------------------------------------------

## Named node inside the visual (art or placeholder), or null.
func visual_node(node_name: String) -> Node:
	if visual_root == null:
		return null
	return visual_root.find_child(node_name, true, false)


## True when this prefab declares the interaction exports (interactive prefab).
func is_interactive() -> bool:
	return interactable != null


## The active collision body: the visual's `Collision` when it supplies one, else the prefab's own.
func collision_body() -> CollisionObject3D:
	if visual_collision != null and is_instance_valid(visual_collision):
		return visual_collision
	return get_node_or_null(^"Collision") as CollisionObject3D


## Merged AABB, in this prefab's space, of every MeshInstance3D at or under `root` (empty AABB if none).
func merged_mesh_aabb(root: Node) -> AABB:
	var out: AABB = AABB()
	if root == null:
		return out
	var first: bool = true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi != null and mi.mesh != null:
			var box: AABB = xform_to_self(mi) * mi.get_aabb()
			out = box if first else out.merge(box)
			first = false
		for c: Node in n.get_children():
			stack.append(c)
	return out


## Transform of `n` relative to this prefab (works whether or not it is in the tree).
func xform_to_self(n: Node) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != self:
		var c3: Node3D = cur as Node3D
		if c3 != null:
			t = c3.transform * t
		cur = cur.get_parent()
	return t


## Collision box (prefab space) fitted to the visual: merged mesh AABB of `_collision_source_node()`
## (or the whole visual), clipped to the room side of the pivot, at least COLLISION_MIN_EXTENT_M
## per axis. Empty AABB when the visual has no meshes there.
func fitted_collision_aabb() -> AABB:
	var src: Node = visual_instance
	var src_name: String = _collision_source_node()
	if src_name != "" and visual_node(src_name) != null:
		src = visual_node(src_name)
	var box: AABB = merged_mesh_aabb(src)
	if box.size == Vector3.ZERO:
		return AABB()
	var lo: Vector3 = box.position
	var hi: Vector3 = box.end
	match _collision_pivot():
		CollisionPivot.FLOOR:
			lo.y = maxf(lo.y, 0.0)
		CollisionPivot.WALL:
			hi.z = minf(hi.z, 0.0)
		CollisionPivot.CEILING:
			hi.y = minf(hi.y, 0.0)
	if hi.x <= lo.x or hi.y <= lo.y or hi.z <= lo.z:
		return AABB()
	for axis: int in range(3):
		var grow: float = COLLISION_MIN_EXTENT_M - (hi[axis] - lo[axis])
		if grow <= 0.0:
			continue
		if axis == Vector3.AXIS_Y and _collision_pivot() == CollisionPivot.FLOOR:
			hi[axis] += grow
		elif axis == Vector3.AXIS_Y and _collision_pivot() == CollisionPivot.CEILING:
			lo[axis] -= grow
		elif axis == Vector3.AXIS_Z and _collision_pivot() == CollisionPivot.WALL:
			lo[axis] -= grow
		else:
			lo[axis] -= grow * 0.5
			hi[axis] += grow * 0.5
	return AABB(lo, hi - lo)


## Box of `size` placed on the pivot (floor: bottom-centre, wall: back-centre, ceiling: top-centre).
func pivot_box(size: Vector3) -> AABB:
	var centre: Vector3 = Vector3.ZERO
	match _collision_pivot():
		CollisionPivot.FLOOR:
			centre = Vector3(0.0, size.y * 0.5, 0.0)
		CollisionPivot.WALL:
			centre = Vector3(0.0, 0.0, -size.z * 0.5)
		CollisionPivot.CEILING:
			centre = Vector3(0.0, -size.y * 0.5, 0.0)
	return AABB(centre - size * 0.5, size)


## Size the prefab's `Collision/Shape` box (see the header). Only for prefabs that declare the
## `collision_size_override` export.
func _fit_collision() -> void:
	if not (&"collision_size_override" in self):
		return
	var own: CollisionObject3D = get_node_or_null(^"Collision") as CollisionObject3D
	if own == null:
		return
	var override: Vector3 = get(&"collision_size_override") as Vector3
	var vis: StaticBody3D = visual_node(VISUAL_COLLISION_NODE) as StaticBody3D
	var box: AABB = AABB()
	if override.x > 0.0 and override.y > 0.0 and override.z > 0.0:
		box = pivot_box(override)
		if vis != null:
			_disable_body(vis)
	elif vis != null:
		vis.collision_layer = own.collision_layer
		vis.collision_mask = own.collision_mask
		_route_hits(vis)
		_disable_body(own)
		visual_collision = vis
		return
	else:
		box = fitted_collision_aabb()
	if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
		return
	var cs: CollisionShape3D = own.get_node_or_null(^"Shape") as CollisionShape3D
	if cs == null:
		Log.error(LOG_CHANNEL, "%s: `Collision` has no `Shape` CollisionShape3D" % name)
		return
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	cs.transform = xform_to_self(own).affine_inverse() * Transform3D(Basis.IDENTITY, box.get_center())


## Turn a collision body fully off (layers, mask and shapes).
static func _disable_body(body: CollisionObject3D) -> void:
	body.collision_layer = 0
	body.collision_mask = 0
	for n: Node in body.find_children("*", "CollisionShape3D", true, false):
		(n as CollisionShape3D).disabled = true


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


## Hits on a child collision body reach this prefab through Damage.find_target (damage.md: the body's
## ancestor implements `take_hit`). The legacy `hit_owner` meta is kept for older lookups only.
func _route_hits(body: Node) -> void:
	if body != null:
		body.set_meta(&"hit_owner", self)


## damage.md: the target publishes its own damage_applied [R] and returns the final DamageInfo.
func _publish_hit(info: Dictionary, attacker_net_id: int) -> Dictionary:
	var out: Dictionary = info.duplicate()
	out["killed"] = false
	if not Net.is_authority():
		out["amount"] = 0.0
		return out
	EventBus.damage_applied.emit(net_id, attacker_net_id, out)
	Net.replicate_event(&"damage_applied", [net_id, attacker_net_id, out])
	return out
