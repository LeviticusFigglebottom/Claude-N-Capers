## Note revealing a keypad code (S9.7; random location per run via the `code_note` slot group).
## Owner: ENV A. Reading shows the code in the prompt and on the HUD (M2).
class_name CodeNote
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/code_note/code_note_placeholder.tscn")

@export var code_group: StringName = &""
@export_group("Interaction")
## -1 = InteractionTweak.read_note_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().read_note_s


func _prefab_ready() -> void:
	interactable.kind = &"read_note"
	# A1-03 behaviour (M2, P2): reveal the code_group code (item_picked_up &"item.code_note").
