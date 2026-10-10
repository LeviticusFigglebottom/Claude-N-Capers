## Code keypad opening a CODE door of the same `code_group` (S9.7). Owner: ENV A.
## Wall-mounted: pivot back-centre, front -Z. Visual: `Panel`, `Led`.
class_name Keypad
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/keypad/keypad_placeholder.tscn")

## Shared with the CODE door(s) and the code_note(s) revealing the code.
@export var code_group: StringName = &""
@export_group("Interaction")
## -1 = InteractionTweak.keypad_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Panel", "Led"])


func _default_interaction_time() -> float:
	return Tweak.interaction().keypad_s


func _prefab_ready() -> void:
	interactable.kind = &"enter_code"
	# A1-03 behaviour (M2, P2): code rolled via GameRng.stream(&"codes"); unlock doors of code_group.
