## Window: breakable glass and/or openable sash (S9.9, S9.11). Owner: ENV A.
## Placed like a door: pivot bottom-centre of the opening (sill), front -Z (UsePoint side).
## Visual: `Frame`, `Glass`, optional `Sash` (pivot for openable). `GlassBody` (world_static)
## blocks movement while the glass is intact. The interaction opens the sash (`openable`);
## breaking (shot/melee) is M2. `noise` is the interaction's noise profile.
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


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Frame", "Glass"])


func _default_interaction_time() -> float:
	return Tweak.interaction().window_open_s


func _prefab_ready() -> void:
	interactable.kind = &"open_window"
	interactable.enabled = openable
	# A1-03 behaviour (M2): sash open, glass break (glass_broken + noise S9.9), police ENTRY use.
