## Keycard reader that opens bound targets (S9.6). Owner: ENV A.
## Wall-mounted: pivot back-centre, front -Z. Visual: `Panel`, `Led`.
## Requires and consumes `item.keycard`; on completion calls `unlock()` and then opens each target
## (`set_open(true)` / `open()`); `Led` turns green. Single use.
## A2-08: a target with `open_by_keycard()` (Safe with the &"keycard" method) gets that call instead.
## Targets may also bind themselves at runtime (`bind_target`, e.g. Safe.reader); each opens once.
## D-103 §6 / QC-55: `set_disabled(true)` kills the reader for a lockdown ("Out of order", no ECM bypass, red Led);
## `set_disabled(false)` restores it. Replicated (`used`, `disabled`).
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
## Mission-forced dead reader (lockdown, D-103 §6).
var disabled: bool = false

## Runtime-bound targets (A2-08, `bind_target`).
var _bound: Array[Node] = []


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Panel", "Led"])


func _default_interaction_time() -> float:
	return Tweak.interaction().keycard_s


func _prefab_ready() -> void:
	interactable.kind = &"keycard"
	interactable.consumes_item = requires_item != &""
	interactable.extra_check = func(_c: Node) -> StringName:
		return InteractableComponent.BLOCK_DISABLED if disabled else InteractableComponent.BLOCK_NONE
	interactable.completed.connect(_on_completed)


## Server: force the reader dead (`on`) or alive again. A dead reader opens nothing, not even with an ECM.
func set_disabled(on: bool) -> void:
	if not Net.is_authority() or disabled == on:
		return
	disabled = on
	_update_led()


## A3-07: replicated state (HeistNetSync).
func _net_state() -> Dictionary:
	return {"used": used, "disabled": disabled, "ie": interactable.enabled if interactable != null else true}


func _apply_net_state(st: Dictionary) -> void:
	used = bool(st.get("used", used))
	disabled = bool(st.get("disabled", disabled))
	if interactable != null and st.has("ie"):
		interactable.enabled = bool(st["ie"])
	_update_led()


## A2-08: add `target` to the nodes opened on completion (no duplicates).
func bind_target(target: Node) -> void:
	if target != null and not _bound.has(target):
		_bound.append(target)


## A2-03 (S8.5, stealth.ecm_opens_doors): an ECM placed on this reader opens it like a keycard
## (EcmSystem calls this after ecm_door_open_s). Server.
func open_by_ecm() -> void:
	_on_completed(null)


func _on_completed(_crew: Node) -> void:
	if not Net.is_authority() or used or disabled:
		return
	used = true
	interactable.enabled = false
	var all: Array[Node] = []
	for path: NodePath in targets:
		var t0: Node = get_node_or_null(path)
		if t0 == null:
			Log.warn(LOG_CHANNEL, "%s: keycard target %s not found" % [name, path])
		elif not all.has(t0):
			all.append(t0)
	for b: Node in _bound:
		if is_instance_valid(b) and not all.has(b):
			all.append(b)
	for t: Node in all:
		if t.has_method(&"open_by_keycard"):
			t.call(&"open_by_keycard")
			continue
		if t.has_method(&"unlock"):
			t.call(&"unlock")
		if t.has_method(&"set_open"):
			t.call(&"set_open", true)
		elif t.has_method(&"open"):
			t.call(&"open")
	_update_led()


## Led: green once used, dark red while disabled, the scene's own colour otherwise.
func _update_led() -> void:
	var led: MeshInstance3D = visual_node("Led") as MeshInstance3D
	if led == null:
		return
	if not used and not disabled:
		led.material_override = null
		return
	var c: Color = Color(0.1, 0.9, 0.2) if used else Color(0.5, 0.02, 0.02)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = used
	m.emission = c
	led.material_override = m
