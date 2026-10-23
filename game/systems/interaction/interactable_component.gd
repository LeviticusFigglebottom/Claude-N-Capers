## Hold-to-interact action on a gameplay prefab or character (S9.1). Owner: ENV A.
## Contract: docs/contracts/gameplay_prefabs.md "Common shape" (child named `Interactable`).
## A node may carry several components (e.g. a guard body: `Interactable` = bag body,
## `PagerInteractable` = answer pager). The highest `priority` available one wins.
## Progress lives on the server (InteractionSystem); this node only describes the action.
## Its global position is the focus point used for aim resolution and look-away checks.
class_name InteractableComponent
extends Node3D

signal started(crew: Node)
signal cancelled(crew: Node)
signal completed(crew: Node)

const BLOCK_NONE: StringName = &""
const BLOCK_CASING: StringName = &"ui.blocked.casing"
const BLOCK_ITEM: StringName = &"ui.blocked.requires_item"
const BLOCK_PHASE: StringName = &"ui.blocked.phase"
const BLOCK_BUSY: StringName = &"ui.blocked.busy"
const BLOCK_DISABLED: StringName = &"ui.blocked.disabled"
const BLOCK_STATE: StringName = &"ui.blocked.state"
## S1.3 (D-065): a civilian (no gear) uses only `civilian_allowed` interactables.
const BLOCK_CIVILIAN: StringName = &"ui.blocked.civilian"

## Interaction kind for events/HUD (&"lockpick", &"answer_pager", &"bag_body", &"take_loot"...).
@export var kind: StringName = &"use"
@export var enabled: bool = true
## Base hold time (s). 0 = instant. Prefabs copy their `interaction_time_s` export here.
@export var interaction_time_s: float = 0.0
@export var requires_item: StringName = &""
@export var consumes_item: bool = false
@export var stealth_only: bool = false
@export var loud_only: bool = false
## The blocked reason shown when stealth_only / loud_only rules it out now (default ui.blocked.phase "Not now"); e.g. the
## OF hoist's "Available after the floor is breached" (P's OF probe).
@export var phase_block_key: StringName = &""
@export var casing_allowed: bool = false
## S1.1: a small item/loot pickup; allowed while casing when the crew has stealth.casing_can_pickup_items.
@export var casing_pickup_item: bool = false
## S1.3: usable in civilian mode (gear pickup; ENV C may flag other prefab instances per map).
@export var civilian_allowed: bool = false
## Noise profile id (InteractionTweak.noise_profiles) emitted when the interaction starts.
@export var noise: StringName = &"silent"
## Strings-table key for the HUD prompt (ui_hud.md).
@export var prompt_key: StringName = &"ui.prompt.interact"
## Optional modifier key scaling the duration (lower = faster), e.g. &"interaction.lockpick_speed_mult".
@export var speed_modifier_key: StringName = &""
@export var priority: int = 0
## Pager juggling (S5.4): several crew members may hold this at once.
@export var allow_multiple: bool = false
## PO6-20: aim tolerance radius (m) around the component: aiming anywhere within it counts as aiming at
## it (a body on the floor, not one point). 0 = a point target.
@export var aim_radius_m: float = 0.0
## Interaction allowed while carrying a bag.
@export var allowed_with_bag: bool = true
## Prefab root this action belongs to (net_id owner). Empty = parent.
@export var owner_path: NodePath
## Per-crew aim filter (crew -> bool): false = this crew member does not target it at all (no prompt, no red
## "can't do that"); unset = everyone. GearPickup: only crew still without gear (B r308 HUD pass).
var aim_filter: Callable = Callable()

## Arguments for prompt_key's string ({name}, ...; LocalHudModel interaction "args"). {key} is filled by the HUD.
var prompt_args: Dictionary = {}
## Optional extra availability check provided by the owning prefab: func(crew: Node) -> StringName.
var extra_check: Callable = Callable()
## Optional duration override: func(crew: Node, base: float) -> float.
var duration_override: Callable = Callable()


func _ready() -> void:
	add_to_group(G.INTERACTABLE)


func owner_node() -> Node:
	if not owner_path.is_empty():
		var n: Node = get_node_or_null(owner_path)
		if n != null:
			return n
	return get_parent()


func owner_net_id() -> int:
	return NetIds.of(owner_node())


## Reason key why `crew` cannot use this now (&"" = available).
func availability(crew: Node) -> StringName:
	var reason: StringName = BLOCK_DISABLED if not enabled or not is_inside_tree() or _owner_disabled() \
		else _phase_block()
	if reason == BLOCK_NONE and crew != null:
		reason = _crew_block(crew)
	if reason == BLOCK_NONE and extra_check.is_valid():
		var r: Variant = extra_check.call(crew)
		if r is StringName:
			reason = r
	return reason


## OF-A2 (QC-61): the owning GameplayPrefab is switched off (GameplayPrefab.set_enabled(false)).
func _owner_disabled() -> bool:
	var o: GameplayPrefab = owner_node() as GameplayPrefab
	return o != null and not o.prefab_enabled


func _phase_block() -> StringName:
	var rt: Node = HeistRuntime.of(self)
	if rt == null:
		return BLOCK_NONE
	var ph: int = int(rt.get(&"phase"))
	var loud: bool = ph == Enums.HeistPhase.LOUD or bool(rt.get(&"went_loud"))
	if (stealth_only and loud) or (loud_only and not loud):
		return phase_block_key if phase_block_key != &"" else BLOCK_PHASE
	return BLOCK_NONE


func _crew_block(crew: Node) -> StringName:
	if int(crew.get(&"crew_state")) != Enums.CrewState.NORMAL:
		return BLOCK_STATE
	if crew.get(&"civilian") == true and not civilian_allowed:
		return BLOCK_CIVILIAN
	if not casing_allowed and not bool(crew.get(&"masked")) and not _casing_pickup_ok(crew):
		return BLOCK_CASING
	if not allowed_with_bag and crew.call(&"is_carrying_bag"):
		return BLOCK_STATE
	if requires_item != &"" and int(crew.call(&"item_count", requires_item)) <= 0:
		return BLOCK_ITEM
	return BLOCK_NONE


func _casing_pickup_ok(crew: Node) -> bool:
	return casing_pickup_item and Modifiers.flag(int(crew.get(&"slot")), &"stealth.casing_can_pickup_items")


## Effective hold time for `crew` (modifiers applied).
func duration_for(crew: Node) -> float:
	var d: float = interaction_time_s
	if duration_override.is_valid():
		d = float(duration_override.call(crew, d))
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	if speed_modifier_key != &"" and slot >= 0:
		d *= Modifiers.mult(slot, speed_modifier_key)
	if slot >= 0:
		d *= Modifiers.mult(slot, &"interaction.speed_mult")  # phase-2 key: every hold
		if kind == &"fix_drill":
			d *= Modifiers.mult(slot, &"interaction.device_fix_speed_mult")  # phase-4 key
	return maxf(d, 0.0)
