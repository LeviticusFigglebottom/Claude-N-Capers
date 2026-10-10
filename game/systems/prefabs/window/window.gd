## Window: breakable glass and/or openable sash (S9.9, S9.11). Owner: ENV A.
## Placed like a door: pivot bottom-centre of the opening (sill), front -Z (UsePoint side).
## Visual: `Frame`, `Glass`, optional `Sash` (pivot for openable). `GlassBody` (world_static)
## blocks movement while the glass is intact. `openable`: the interaction (kind &"open_window")
## slides the `Sash` up / down (GlassBody off while open). Not openable but `breakable`: the
## interaction smashes the glass (kind &"break_window", InteractionTweak.glass_break_s unless
## `interaction_time_s` is set). Shooting a breakable window (`take_hit`, damage.md) breaks it too:
## `Glass` hidden, GlassBody off, glass_broken [R], 15 m noise, `broken_glass` stimulus (S9.9).
## `noise` is the interaction's noise profile.
class_name WindowPrefab
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/window/window_placeholder.tscn")

@export var breakable: bool = true
@export var openable: bool = false
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
var _sash_closed_y: float = 0.0


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Frame", "Glass"])


func _default_interaction_time() -> float:
	return Tweak.interaction().window_open_s


func _prefab_ready() -> void:
	_route_hits(get_node_or_null(^"GlassBody"))
	var sash: Node3D = visual_node("Sash") as Node3D
	if sash != null:
		_sash_closed_y = sash.position.y
	interactable.completed.connect(_on_completed)
	_apply_state()
	# A1-03 behaviour (M2): police ENTRY use.


## Server: open/close the sash (openable windows).
func set_open(open: bool) -> void:
	if not Net.is_authority() or not openable:
		return
	is_open = open
	var sash: Node3D = visual_node("Sash") as Node3D
	if sash != null:
		sash.position.y = _sash_closed_y + (Tweak.interaction().window_sash_open_m if open else 0.0)
	_set_glass_collision(not open and not broken)


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


func _set_glass_collision(on: bool) -> void:
	var body: StaticBody3D = get_node_or_null(^"GlassBody") as StaticBody3D
	if body != null:
		body.collision_layer = LAYER_WORLD_STATIC if on else 0


func _on_completed(crew: Node) -> void:
	if not Net.is_authority():
		return
	if openable:
		set_open(not is_open)
	else:
		break_glass(NetIds.of(crew))
