## Loot spawn: a stack the crew bags up and carries (gameplay_prefabs.md `loot_spawn`). Owner: ENV A.
## Interaction = "bag it" (InteractionTweak.bag_loot_s); `count` bags can be taken from it.
## Floor object: pivot bottom-centre. The UsePoint must be on the navmesh (heist_map.md §3).
## Behaviour (A1-07): each completion spawns a LootBag of `loot_id` (`moved = true`) through
## LootManager and puts it straight on the crew member's back; disabled once `remaining` is 0.
## Not usable while already carrying a bag.
## D-103 §6 / QC-54: `alarm_on_take` (frame sensors) raises alarm_raised(&"sensor") when a bag is taken before the
## heist went loud, unless its `alarm_group` was disabled (AlarmGroups.disable: a hack, the mission).
class_name LootSpawn
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/loot_spawn/loot_spawn_placeholder.tscn")
const PROMPT_CUT: StringName = &"ui.prompt.cut_painting"

## LootDef id of the bags this spawn produces.
@export var loot_id: StringName = &""
@export var count: int = 1
## D-103 §6: taking from this spawn trips its sensor (alarm &"sensor") while `alarm_group` is live.
@export var alarm_on_take: bool = false
@export var alarm_group: StringName = &""
## Prompt for the take (&"" = the interaction's own; a painting loot_id defaults to PROMPT_CUT: "cut the painting").
@export var prompt_key: StringName = &""
@export_group("Interaction")
## -1 = InteractionTweak.bag_loot_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var remaining: int = 0


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().bag_loot_s


func _prefab_ready() -> void:
	remaining = count
	interactable.kind = &"bag_loot"
	var pk: StringName = prompt_key
	if pk == &"" and String(loot_id).begins_with("loot.painting"):
		pk = PROMPT_CUT  # GN canvases: "Hold F to cut the painting" (ENV B string)
	if pk != &"":
		interactable.prompt_key = pk
	interactable.allowed_with_bag = false
	interactable.enabled = remaining > 0
	interactable.completed.connect(_on_completed)


func _on_completed(crew: Node) -> void:
	var c: CrewController = crew as CrewController
	if not Net.is_authority() or c == null or remaining <= 0 or c.is_carrying_bag():
		return
	var mgr: LootManager = HeistRuntime.get_service(G.SVC_LOOT) as LootManager
	if mgr == null:
		return
	var bag: LootBag = mgr.spawn_bag(loot_id, Transform3D(Basis.IDENTITY, c.global_position), true)
	if bag == null:
		return
	remaining -= 1
	mgr.carry(bag, c)
	_check_sensor()
	if remaining <= 0:
		interactable.enabled = false
		if visual_root != null:
			visual_root.visible = false


## Server: an alarmed take in a live group raises the alarm (no effect once loud).
func _check_sensor() -> void:
	if not alarm_on_take:
		return
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt == null or rt.went_loud or not AlarmGroups.is_live(rt, alarm_group):
		return
	_raise_alarm(AlarmGroups.REASON_SENSOR, net_id)
