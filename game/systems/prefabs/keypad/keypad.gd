## Code keypad opening CODE doors (S9.7). Owner: ENV A.
## Wall-mounted: pivot back-centre, front -Z. Visual: `Panel`, `Led`.
## The code of `code_group` is rolled per run (CodeRegistry, GameRng &"codes"). While the crew does
## not know it (no code_note of the group read yet) the keypad is blocked with
## `ui.blocked.code_unknown`. Known: entering it takes keypad_s (kind &"enter_code"), then every
## target is unlocked and opened: `targets` (Door / Safe / anything with unlock + set_open/open or
## open_by_device), plus every Door in the heist with lock CODE and the same `code_group`.
## `Led` turns green. Single use. An empty `code_group` needs no code (plain door button).
## Variant slots may instance it with params {"code_group": &"..."} (configure_variant).
class_name Keypad
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/keypad/keypad_placeholder.tscn")

## Shared with the CODE door(s) and the code_note(s) revealing the code.
@export var code_group: StringName = &""
## Extra things this keypad opens (A2-04).
@export var targets: Array[NodePath] = []
@export_group("Interaction")
## -1 = InteractionTweak.keypad_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
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
	return Tweak.interaction().keypad_s


func _prefab_ready() -> void:
	interactable.kind = &"enter_code"
	interactable.prompt_key = &"ui.prompt.enter_code"
	interactable.extra_check = _availability
	interactable.completed.connect(_on_completed)


## VariantSlot params (heist_map.md §5): {"code_group": StringName}.
func configure_variant(params: Dictionary) -> void:
	if params.has("code_group"):
		code_group = StringName(params["code_group"])


## Everything this keypad opens: `targets` + CODE doors of `code_group`.
func resolved_targets() -> Array[Node]:
	var out: Array[Node] = []
	for path: NodePath in targets:
		var t: Node = get_node_or_null(path)
		if t == null:
			Log.warn(LOG_CHANNEL, "%s: keypad target %s not found" % [name, path])
		elif not out.has(t):
			out.append(t)
	if code_group == &"":
		return out
	var rt: HeistRuntime = HeistRuntime.of(self)
	var root: Node = rt.map if rt != null and rt.map != null else get_parent()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var d: Door = n as Door
		if d != null and d.lock == Door.Lock.CODE and d.code_group == code_group and not out.has(d):
			out.append(d)
		for c: Node in n.get_children():
			stack.append(c)
	return out


func _availability(_crew: Node) -> StringName:
	if used:
		return InteractableComponent.BLOCK_DISABLED
	if code_group == &"":
		return InteractableComponent.BLOCK_NONE
	var reg: CodeRegistry = CodeRegistry.of(self)
	if reg == null or not reg.is_known(code_group):
		return CodeRegistry.BLOCK_CODE_UNKNOWN
	return InteractableComponent.BLOCK_NONE


func _on_completed(_crew: Node) -> void:
	if not Net.is_authority() or used:
		return
	used = true
	interactable.enabled = false
	for t: Node in resolved_targets():
		if t.has_method(&"open_by_device"):
			t.call(&"open_by_device")
			continue
		if t.has_method(&"unlock"):
			t.call(&"unlock")
		if t.has_method(&"set_open"):
			t.call(&"set_open", true)
		elif t.has_method(&"open"):
			t.call(&"open")
	_cue(&"cue.keypad_accept", global_position)
	var led: MeshInstance3D = visual_node("Led") as MeshInstance3D
	if led != null:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.1, 0.9, 0.2)
		m.emission_enabled = true
		m.emission = Color(0.1, 0.9, 0.2)
		led.material_override = m
