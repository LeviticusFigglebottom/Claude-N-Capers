## Keycard reader that opens bound targets (S9.6). Owner: ENV A.
## Wall-mounted: pivot back-centre, front -Z. Visual: `Panel`, `Led`.
## Requires and consumes `item.keycard`; on completion calls `unlock()` and then opens each target
## (`set_open(true)` / `open()`); `Led` turns green. Single use.
class_name KeycardReader
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/keycard_reader/keycard_reader_placeholder.tscn")

## Doors / vaults this reader opens.
@export var targets: Array[NodePath] = []
@export_group("Interaction")
## -1 = InteractionTweak.keycard_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &"item.keycard"
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var used: bool = false


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Panel", "Led"])


func _default_interaction_time() -> float:
	return Tweak.interaction().keycard_s


func _prefab_ready() -> void:
	interactable.kind = &"keycard"
	interactable.consumes_item = requires_item != &""
	interactable.completed.connect(_on_completed)


func _on_completed(_crew: Node) -> void:
	if not Net.is_authority() or used:
		return
	used = true
	interactable.enabled = false
	for path: NodePath in targets:
		var t: Node = get_node_or_null(path)
		if t == null:
			Log.warn(LOG_CHANNEL, "%s: keycard target %s not found" % [name, path])
			continue
		if t.has_method(&"unlock"):
			t.call(&"unlock")
		if t.has_method(&"set_open"):
			t.call(&"set_open", true)
		elif t.has_method(&"open"):
			t.call(&"open")
	var led: MeshInstance3D = visual_node("Led") as MeshInstance3D
	if led != null:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.1, 0.9, 0.2)
		m.emission_enabled = true
		m.emission = Color(0.1, 0.9, 0.2)
		led.material_override = m
