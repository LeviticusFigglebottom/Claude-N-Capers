## Glass display case holding small loot (gameplay_prefabs.md `display_case`). Owner: ENV A.
## Break the glass (S9.9: loud stimulus + noise) or open it with a key to reach the loot.
## Visual: `Body`, `Glass` (MeshInstance3D(s); A hides them and spawns shatter), `LootAnchor`
## marker(s). Floor object: pivot bottom-centre, front -Z.
class_name DisplayCase
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/display_case/display_case_placeholder.tscn")

## LootDef id of the small loot inside.
@export var loot_id: StringName = &""
## Breaking the glass raises the alarm (alarmed case) in addition to the S9.9 stimulus.
@export var glass_breaks_alarm: bool = false
@export_group("Interaction")
## -1 = InteractionTweak.display_case_open_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var glass_broken: bool = false


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Body", "Glass", "LootAnchor"])


func _default_interaction_time() -> float:
	return Tweak.interaction().display_case_open_s


func _prefab_ready() -> void:
	interactable.kind = &"open_case"
	# A1-03 behaviour (M2): glass break (S9.9 glass_broken + noise), open, small loot at LootAnchor.
