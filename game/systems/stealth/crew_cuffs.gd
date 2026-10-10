## S3.2 (P2) cuffs on one crew member: child `Cuffs` of a CrewController, created on first use by
## `CrewCuffs.of(crew, true)` (a guard about to cuff). Owner: ENV A. Server-authoritative.
## - `cuff(by_net_id)`: CrewState.CUFFED (cannot move, shoot or interact; the StealthDirector no
##   longer observes them; LootManager drops the carried bag), starts the per-crew-member cooldown
##   (StealthTweak.cuff_cooldown_s, 4 min: guards spotting them meanwhile radio straight away).
## - Free: automatically after cuff_self_free_s (60 s, PD2 "escaping takes 60 s"), or a teammate
##   holds the sibling `UncuffInteractable` (kind &"uncuff", uncuff_s) on them.
## - Any other state change (downed, custody) ends the cuffs without touching that state.
## Signals are local; crew_state_changed on the CrewController is the replicated-by-sync source.
class_name CrewCuffs
extends Node

signal cuffed(by_net_id: int)
signal freed(by_slot: int)

const NODE_NAME: String = "Cuffs"
const INTERACTABLE_NAME: String = "UncuffInteractable"

## Seconds until the crew member frees themselves (0 when not cuffed).
var cuffed_left: float = 0.0
## Seconds until guards may cuff this crew member again (S3.2 cooldown).
var cooldown_left: float = 0.0
## Net id of the guard that applied the cuffs (0 when not cuffed).
var cuffed_by_net_id: int = 0

var _crew: CrewController = null
var _uncuff: InteractableComponent = null


## The crew member's cuffs component (created when `create`; null otherwise when missing).
static func of(crew: Node, create: bool = false) -> CrewCuffs:
	if crew == null:
		return null
	var c: CrewCuffs = crew.get_node_or_null(NODE_NAME) as CrewCuffs
	if c == null and create and crew is CrewController:
		c = CrewCuffs.new()
		c.name = NODE_NAME
		crew.add_child(c)
	return c


## True when guards may cuff `crew` now (NORMAL state, no cooldown running).
static func can_cuff(crew: CrewController) -> bool:
	if crew == null or crew.crew_state != Enums.CrewState.NORMAL:
		return false
	var c: CrewCuffs = of(crew)
	return c == null or c.cooldown_left <= 0.0


func _ready() -> void:
	_crew = get_parent() as CrewController
	if _crew == null:
		Log.error(&"stealth", "CrewCuffs must be a child of a CrewController")
		return
	_crew.crew_state_changed.connect(_on_crew_state_changed)
	_uncuff = InteractableComponent.new()
	_uncuff.name = INTERACTABLE_NAME
	_uncuff.kind = &"uncuff"
	_uncuff.prompt_key = &"ui.prompt.uncuff"
	_uncuff.priority = 100
	_uncuff.casing_allowed = true
	_uncuff.enabled = false
	_uncuff.interaction_time_s = Tweak.stealth().uncuff_s
	_uncuff.extra_check = _uncuff_check
	_uncuff.completed.connect(_on_uncuff_completed)
	_uncuff.position = Vector3(0.0, 1.0, 0.0)
	_crew.add_child.call_deferred(_uncuff)


func is_cuffed() -> bool:
	return _crew != null and _crew.crew_state == Enums.CrewState.CUFFED


## Server: cuff the crew member (guard S3.2). Returns false when not allowed now.
func cuff(by_net_id: int) -> bool:
	if _crew == null or not Net.is_authority() or not CrewCuffs.can_cuff(_crew):
		return false
	var tw: StealthTweak = Tweak.stealth()
	cuffed_left = tw.cuff_self_free_s
	cooldown_left = tw.cuff_cooldown_s
	cuffed_by_net_id = by_net_id
	_crew.set_crew_state(Enums.CrewState.CUFFED)
	if _uncuff != null:
		_uncuff.enabled = true
	cuffed.emit(by_net_id)
	Log.info(&"stealth", "slot %d cuffed by %d" % [_crew.slot, by_net_id])
	return true


## Server: free the crew member (-1 = broke free alone). No-op unless CUFFED.
func free_crew(by_slot: int = -1) -> void:
	if _crew == null or not Net.is_authority() or not is_cuffed():
		return
	_end()
	_crew.set_crew_state(Enums.CrewState.NORMAL)
	freed.emit(by_slot)
	Log.info(&"stealth", "slot %d freed from cuffs (by %d)" % [_crew.slot, by_slot])


func _physics_process(delta: float) -> void:
	if _crew == null or not Net.is_authority():
		return
	if cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)
	if not is_cuffed():
		return
	cuffed_left -= delta
	if cuffed_left <= 0.0:
		free_crew(-1)


func _end() -> void:
	cuffed_left = 0.0
	cuffed_by_net_id = 0
	if _uncuff != null:
		_uncuff.enabled = false
		var rt: HeistRuntime = HeistRuntime.of(_crew)
		if rt != null and rt.interaction != null:
			rt.interaction.cancel_all_on(_uncuff)


func _on_crew_state_changed(old_state: int, new_state: int) -> void:
	if old_state == Enums.CrewState.CUFFED and new_state != Enums.CrewState.CUFFED and cuffed_left > 0.0:
		_end()  # downed / custody / freed elsewhere


func _uncuff_check(helper: Node) -> StringName:
	if not is_cuffed():
		return InteractableComponent.BLOCK_DISABLED
	if helper == _crew:
		return InteractableComponent.BLOCK_STATE
	return InteractableComponent.BLOCK_NONE


func _on_uncuff_completed(helper: Node) -> void:
	free_crew(int(helper.get(&"slot")) if helper != null else -1)
