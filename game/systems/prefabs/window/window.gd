## Window: breakable glass and/or openable sash (S9.9, S9.11). Owner: ENV A.
## Placed like a door: pivot bottom-centre of the opening (sill), front -Z (UsePoint side).
## Visual: `Frame`, `Glass`, optional `Sash` (pivot for openable). `GlassBody` (world_static)
## blocks movement while the glass is intact. `openable`: the interaction (kind &"open_window")
## slides the `Sash` up / down (GlassBody off while open). Not openable but `breakable`: the
## interaction smashes the glass (kind &"break_window", InteractionTweak.glass_break_s unless
## `interaction_time_s` is set). Shooting a breakable window (`take_hit`, damage.md) breaks it too:
## `Glass` hidden, GlassBody off, glass_broken [R], 15 m noise, `broken_glass` stimulus (S9.9).
## `noise` is the interaction's noise profile.
## A2-08: at ready the `GlassBody` box is fitted to the visual's `Glass`: the merged AABB of every
## MeshInstance3D at or under `Glass` (in this prefab's space, sash closed). Depth is at least
## GLASS_MIN_DEPTH_M. Without a Glass mesh the saved 1.0 x 1.2 m box stays.
class_name WindowPrefab
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/window/window_placeholder.tscn")
## Minimum GlassBody depth (m) so thin glass still blocks movement.
const GLASS_MIN_DEPTH_M: float = 0.05

@export var breakable: bool = true
@export var openable: bool = false
## QC-61 walk-through window (sill <= 0.35 m, e.g. the Glasshouse fire-escape door-window): a layer-1
## NavLink through the opening, enabled while it is passable (sash open or glass broken), so every
## agent may path through it then and none while it is shut.
@export var walkable: bool = false
## How far the sash slides up when opened (m); -1 = InteractionTweak.window_sash_open_m. Tall door-windows
## (e.g. the Glasshouse fire-escape one) set their own travel.
@export var sash_travel_m: float = -1.0
@export_group("Interaction")
## -1 = InteractionTweak.window_open_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var is_open: bool = false
var broken: bool = false

var _glass_stim_id: int = 0
var _nav_link: NavigationLink3D = null
var _sash_closed_y: float = 0.0


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Frame", "Glass"])


func _default_interaction_time() -> float:
	return Tweak.interaction().window_open_s


func _prefab_ready() -> void:
	var glass_body: Node = get_node_or_null(^"GlassBody")
	_route_hits(glass_body)
	if glass_body != null:
		glass_body.add_to_group(StealthDirector.GROUP_SEE_THROUGH)  # D-142: guards see through intact glass
	_fit_glass_body()
	var sash: Node3D = visual_node("Sash") as Node3D
	if sash != null:
		_sash_closed_y = sash.position.y
	interactable.completed.connect(_on_completed)
	if walkable:
		_nav_link = NavigationLink3D.new()
		_nav_link.name = "NavLink"
		var half: float = Tweak.interaction().door_nav_link_half_m
		_nav_link.start_position = Vector3(0.0, 0.0, -half)
		_nav_link.end_position = Vector3(0.0, 0.0, half)
		_nav_link.bidirectional = true
		_nav_link.navigation_layers = 1
		add_child(_nav_link)
	_apply_state()
	_set_glass_collision(not is_open and not broken)
	# A1-03 behaviour (M2): police ENTRY use.


## Server: open/close the sash (openable windows).
func set_open(open: bool) -> void:
	if not Net.is_authority() or not openable:
		return
	is_open = open
	var sash: Node3D = visual_node("Sash") as Node3D
	if sash != null:
		sash.position.y = _sash_closed_y + (_sash_travel() if open else 0.0)
	_set_glass_collision(not open and not broken)


## Client (A3-07, HeistNetSync): mirror `broken` / `is_open` (glass, sash, collision, prompt).
func _apply_net_state(state: Dictionary) -> void:
	if bool(state.get("broken", broken)) and not broken:
		broken = true
		var glass: Node3D = visual_node("Glass") as Node3D
		if glass != null:
			glass.visible = false
		_apply_state()
	if state.has("is_open") and openable:
		is_open = bool(state["is_open"])
		var sash: Node3D = visual_node("Sash") as Node3D
		if sash != null:
			sash.position.y = _sash_closed_y + (_sash_travel() if is_open else 0.0)
	_set_glass_collision(not is_open and not broken)


## Server: smash the glass (S9.9).
func break_glass(_by_net_id: int = 0) -> void:
	if not Net.is_authority() or broken or not breakable:
		return
	broken = true
	var glass: Node3D = visual_node("Glass") as Node3D
	var pos: Vector3 = glass.global_position if glass != null else global_position + Vector3.UP * 0.6
	if glass != null:
		glass.visible = false
	_set_glass_collision(false)
	_glass_stim_id = _shatter_glass(pos)
	_apply_state()


## Combat hook: hits break a breakable window.
func take_hit(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	if Net.is_authority():
		break_glass(attacker_net_id)
	return _publish_hit(info, attacker_net_id)


## Deprecated alias of take_hit (pre-D-026 callers).
func apply_damage(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	return take_hit(info, attacker_net_id)


func _exit_tree() -> void:
	var st: StealthDirector = _stealth()
	if st != null and _glass_stim_id != 0:
		st.unregister_stimulus(_glass_stim_id)
	_glass_stim_id = 0


func _apply_state() -> void:
	if openable:
		interactable.kind = &"open_window"
		interactable.enabled = true
	elif breakable and not broken:
		interactable.kind = &"break_window"
		interactable.prompt_key = &"ui.prompt.break_glass"
		interactable.interaction_time_s = interaction_time_s if interaction_time_s >= 0.0 else Tweak.interaction().glass_break_s
		interactable.enabled = true
	else:
		interactable.enabled = false


## A2-08: the glass AABB in this prefab's space (merged over Glass meshes), or an empty AABB.
func glass_aabb() -> AABB:
	return merged_mesh_aabb(visual_node("Glass"))


func _fit_glass_body() -> void:
	var cs: CollisionShape3D = get_node_or_null(^"GlassBody/Shape") as CollisionShape3D
	if cs == null:
		return
	var box: AABB = glass_aabb()
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(box.size.x, box.size.y, maxf(box.size.z, GLASS_MIN_DEPTH_M))
	cs.shape = shape
	var parent3d: Node3D = cs.get_parent() as Node3D
	cs.transform = Transform3D(Basis.IDENTITY, xform_to_self(parent3d).affine_inverse() * box.get_center())


func _set_glass_collision(on: bool) -> void:
	var body: StaticBody3D = get_node_or_null(^"GlassBody") as StaticBody3D
	if body != null:
		body.collision_layer = LAYER_WORLD_STATIC if on else 0
	if _nav_link != null:
		_nav_link.enabled = not on  # QC-61: passable exactly when the glass no longer blocks


func _sash_travel() -> float:
	return sash_travel_m if sash_travel_m >= 0.0 else Tweak.interaction().window_sash_open_m


## The walk-through NavLink (`walkable`), else null.
func nav_link() -> NavigationLink3D:
	return _nav_link


func _on_completed(crew: Node) -> void:
	if not Net.is_authority():
		return
	if openable:
		set_open(not is_open)
	else:
		break_glass(NetIds.of(crew))
