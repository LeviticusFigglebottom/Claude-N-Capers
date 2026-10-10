## Glass display case holding small loot (gameplay_prefabs.md `display_case`). Owner: ENV A.
## Break the glass (S9.9: loud stimulus + noise) or open it with a key to reach the loot.
## Visual: `Body`, `Glass` (MeshInstance3D(s); A hides them and spawns shatter), `LootAnchor`
## marker(s). Floor object: pivot bottom-centre, front -Z.
## Behaviour: the Interactable smashes the glass (kind &"break_glass", InteractionTweak.glass_break_s
## unless `interaction_time_s` is set) or, with `requires_item`, opens it with that key (kind
## &"open_case", no glass break). Shooting the case (`apply_damage`) also breaks the glass. Breaking:
## `Glass` hidden, glass_broken [R], 15 m noise, `broken_glass` stimulus; `glass_breaks_alarm` raises
## alarm_raised(&"glass_alarm"). Then the same Interactable takes the loot (kind &"take_loot",
## small_loot_s) -> small_loot_taken(value, slot) [R]; value = ContentDB.loot(loot_id).value, else
## LootTweak.display_case_default_value.
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
var opened: bool = false
var taken: bool = false

var _glass_stim_id: int = 0


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Body", "Glass", "LootAnchor"])


func _default_interaction_time() -> float:
	return Tweak.interaction().display_case_open_s


func _prefab_ready() -> void:
	_route_hits(get_node_or_null(^"Collision"))
	interactable.completed.connect(_on_completed)
	_apply_state()


## Payout of the loot inside (integer dollars).
func loot_value() -> int:
	if loot_id != &"":
		var info: Dictionary = LootManager.loot_info(loot_id)
		if bool(info.get("known", false)):
			return int(info["value"])
	return LootTweak.get_default().display_case_default_value


## Server: smash the glass (interaction, gunfire, melee). S9.9.
func break_glass(by_net_id: int = 0) -> void:
	if not Net.is_authority() or glass_broken:
		return
	glass_broken = true
	var glass: Node3D = visual_node("Glass") as Node3D
	var pos: Vector3 = glass.global_position if glass != null else global_position + Vector3.UP
	if glass != null:
		glass.visible = false
	_glass_stim_id = _shatter_glass(pos)
	if glass_breaks_alarm:
		_raise_alarm(&"glass_alarm", by_net_id if by_net_id != 0 else net_id)
	_apply_state()


## Combat hook: any hit breaks the glass.
func apply_damage(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	var out: Dictionary = info.duplicate()
	out["killed"] = false
	break_glass(attacker_net_id)
	return out


func _exit_tree() -> void:
	var st: StealthDirector = _stealth()
	if st != null and _glass_stim_id != 0:
		st.unregister_stimulus(_glass_stim_id)
	_glass_stim_id = 0


func _apply_state() -> void:
	var tw: InteractionTweak = Tweak.interaction()
	interactable.consumes_item = false
	if taken:
		interactable.enabled = false
	elif glass_broken or opened:
		interactable.kind = &"take_loot"
		interactable.prompt_key = &"ui.prompt.take_loot"
		interactable.interaction_time_s = tw.small_loot_s
		interactable.requires_item = &""
		interactable.noise = &"silent"
	elif requires_item != &"":
		interactable.kind = &"open_case"
		interactable.interaction_time_s = interaction_time_s if interaction_time_s >= 0.0 else tw.display_case_open_s
	else:
		interactable.kind = &"break_glass"
		interactable.prompt_key = &"ui.prompt.break_glass"
		interactable.interaction_time_s = interaction_time_s if interaction_time_s >= 0.0 else tw.glass_break_s


func _on_completed(crew: Node) -> void:
	if not Net.is_authority() or taken:
		return
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	if glass_broken or opened:
		taken = true
		var anchor: Node3D = visual_node("LootAnchor") as Node3D
		if anchor != null:
			for c: Node in anchor.get_children():
				if c is Node3D:
					(c as Node3D).visible = false
		_emit_fact(&"small_loot_taken", [loot_value(), slot])
		_apply_state()
	elif requires_item != &"":
		opened = true
		_apply_state()
	else:
		var c: CrewController = crew as CrewController
		break_glass(c.net_id if c != null else 0)
