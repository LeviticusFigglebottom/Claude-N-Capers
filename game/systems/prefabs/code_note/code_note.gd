## Note revealing a keypad code (S9.7; random location per run via the `code_note` slot group).
## Owner: ENV A. Reading it (kind &"read_note", read_note_s) reveals `code_group`'s code to the
## whole crew (CodeRegistry.reveal) and emits item_picked_up(&"item.code_note", slot) [R]. The note
## stays readable. `code_text()` is the 4-digit code for the prompt / HUD (CodeRegistry.known_codes()).
## Variant slots may instance it with params {"code_group": &"...", "reveals_variant_group": &"..."} (configure_variant).
## QC-63 (OF's manager planner `[code_hint]`): `reveals_variant_group` also reveals a variant group on read (PreplanAssets
## .reveal_group, the same effect as an intel asset's `reveals`; HeistMission._on_variant_revealed). A note may carry
## only that (no `code_group`).
class_name CodeNote
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/code_note/code_note_placeholder.tscn")

@export var code_group: StringName = &""
## QC-63: variant group revealed when read (&"" = none), e.g. &"code_pc".
@export var reveals_variant_group: StringName = &""
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
	interactable.prompt_key = &"ui.prompt.read_note"
	interactable.completed.connect(_on_completed)


## VariantSlot params (heist_map.md §5): {"code_group": StringName}.
func configure_variant(params: Dictionary) -> void:
	if params.has("code_group"):
		code_group = StringName(params["code_group"])
	if params.has("reveals_variant_group"):
		reveals_variant_group = StringName(params["reveals_variant_group"])


## The code written on this note ("" without a heist or group).
func code_text() -> String:
	var reg: CodeRegistry = CodeRegistry.of(self)
	if reg == null or code_group == &"":
		return ""
	return reg.code_for(code_group)


func _on_completed(crew: Node) -> void:
	if not Net.is_authority():
		return
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	var rt: HeistRuntime = HeistRuntime.of(self)
	if reveals_variant_group != &"" and rt != null:
		rt.preplan.reveal_group(reveals_variant_group)
	var reg: CodeRegistry = CodeRegistry.of(self)
	if code_group != &"" and reg != null:
		reg.reveal(code_group, slot)
	elif reveals_variant_group == &"" or rt == null:
		Log.warn(LOG_CHANNEL, "%s: code note without a code_group / reveals_variant_group / heist" % name)
		return
	_emit_fact(&"item_picked_up", [CodeRegistry.NOTE_ITEM, slot])
