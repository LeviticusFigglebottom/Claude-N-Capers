## Keycard lying in the map (S9.6; random location per run via the `keycard` slot group). Owner: ENV A.
## Interaction completes -> crew gets `item.keycard`, item_picked_up [R], the prefab frees itself.
## Usable while casing (casing_allowed defaults to true here).
## QC-52 (Gallery Night curator): with `carrier_tag` set, the card is on the NPC whose spawn tags contain it. It follows
## that NPC, hidden and not interactable, until the carrier is dead, tied, intimidated to the floor or dominated
## (server decides, `released` replicated); then it shows on them (a 1 s take, carried_item_s) and, once the carrier
## is dead, stays on the floor where they fell (bagging the body does not take it). PD2: tie or kill the keyholder.
## No NPC with the tag once the heist runs: an ordinary pickup where it was placed.
class_name KeycardPickup
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/keycard_pickup/keycard_pickup_placeholder.tscn")
const ITEM: StringName = &"item.keycard"
## Height above the carrier's origin while it follows them (m).
const CARRY_HEIGHT_M: float = 0.9
const DROP_HEIGHT_M: float = 0.05

@export_group("Interaction")
## -1 = InteractionTweak.item_pickup_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = true
@export var noise: StringName = &"silent"
@export_group("Carried (QC-52)")
## Spawn tag of the NPC carrying this card (&"" = lying in the map).
@export var carrier_tag: StringName = &""

var taken: bool = false
## Net id of the carrying NPC (0 = none / not resolved yet).
var carrier_id: int = 0
## True once the carrier is dead or subdued: the card can be taken.
var released: bool = false
var _carrier_resolved: bool = false


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().item_pickup_s


func _prefab_ready() -> void:
	interactable.kind = &"pickup_item"
	interactable.completed.connect(_on_completed)
	if carrier_tag != &"":
		_set_carried_look(true)


func _physics_process(_delta: float) -> void:
	if carrier_tag == &"" or taken:
		return
	if Net.is_authority() and not _carrier_resolved:
		_resolve_carrier()
	var npc: NpcBase = Ids.lookup(carrier_id) as NpcBase if carrier_id != 0 else null
	if npc == null or not is_instance_valid(npc):
		return
	if not npc.alive:
		if not released and Net.is_authority():
			_release()
		if not has_meta(&"dropped"):  # once, where the body fell: bagging the body leaves the card behind
			set_meta(&"dropped", true)
			global_position = npc.global_position + Vector3.UP * DROP_HEIGHT_M
		return
	global_position = npc.global_position + Vector3.UP * CARRY_HEIGHT_M
	if not released and Net.is_authority() and subdued(npc):
		_release()


## Server (mission): remove this card for the rest of the run (Gallery Night curator_tipsy: her lanyard is on the
## bar instead, one card in all). The despawn replicates.
func discard() -> void:
	if not Net.is_authority() or taken:
		return
	taken = true
	queue_free()


## True when `npc` (alive) can be relieved of what it carries: tied, intimidated to the floor, dominated, surrendered.
static func subdued(npc: NpcBase) -> bool:
	if npc == null or not npc.alive:
		return true
	var brain: Node = npc.get_node_or_null(^"Brain")
	if brain != null:
		if brain.has_method(&"is_tied") and bool(brain.call(&"is_tied")):
			return true
		if brain.has_method(&"is_down") and bool(brain.call(&"is_down")):
			return true
		var dom: Variant = brain.get(&"dominated_by_slot")
		if dom is int and int(dom) >= 0:
			return true
	for c: Node in npc.get_children():
		var sur: Variant = c.get(&"surrendered_by_slot")
		if sur is int and int(sur) >= 0:
			return true
	return false


func _resolve_carrier() -> void:
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt == null or rt.phase == Enums.HeistPhase.LOADING:
		return
	_carrier_resolved = true
	for n: Node in rt.npcs():
		var npc: NpcBase = n as NpcBase
		var tags: Variant = npc.spawn_info.get("tags", [])
		if tags is Array and (tags as Array).has(carrier_tag):
			carrier_id = npc.net_id
			Log.info(LOG_CHANNEL, "%s carried by %s" % [name, npc.name])
			return
	Log.warn(LOG_CHANNEL, "%s: no NPC tagged '%s'; left where it was placed" % [name, carrier_tag])
	_release()


func _release() -> void:
	released = true
	_set_carried_look(false)


func _set_carried_look(carried: bool) -> void:
	visible = not carried
	if interactable != null:
		interactable.enabled = not carried
		if carrier_tag != &"" and not carried:
			interactable.interaction_time_s = Tweak.interaction().carried_item_s


func _net_state() -> Dictionary:
	return {"taken": taken, "cr": carrier_id, "rel": released}


func _apply_net_state(d: Dictionary) -> void:
	taken = bool(d.get("taken", taken))
	carrier_id = int(d.get("cr", carrier_id))
	var rel: bool = bool(d.get("rel", released))
	if carrier_tag == &"" or rel == released:
		return
	released = rel
	_set_carried_look(not rel)


func _on_completed(crew: Node) -> void:
	if not Net.is_authority() or taken:
		return
	var c: CrewController = crew as CrewController
	if c == null:
		return
	taken = true
	c.add_item(ITEM)
	_emit_fact(&"item_picked_up", [ITEM, c.slot])
	queue_free()
