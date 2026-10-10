## S6.4: restrained NPCs are themselves suspicious. HeistRuntime child (node "HostageStimuli", not a
## published service: it only listens). Owner: ENV A. Row S6.4 (A2-07).
##
## Server: keys off EventBus.npc_alert_state_changed generically, so it works for any flow that
## puts a non-civilian NPC (guard, police...) into DOMINATED / SURRENDERED / TIED (shout domination,
## the cuff flow, hostage scripts): while the NPC is in one of those states a `hostage` stimulus is
## registered on it (StealthTweak.stimuli: guards -> alarm, civilians -> panic). Any other state
## (including DEAD, where the corpse stimulus takes over, and CONVERTED) unregisters it.
## Tied civilians are handled by CivilianBrain itself (`restrained` stimulus on tie, removed when
## freed or killed), so this service skips the civilian role.
## A source that already carries a `hostage` stimulus (registered by another system) is left alone.
class_name HostageStimuli
extends Node

const KIND: StringName = &"hostage"
const RESTRAINED_STATES: Array[int] = [
	Enums.AlertState.DOMINATED, Enums.AlertState.SURRENDERED, Enums.AlertState.TIED,
]

var _runtime: HeistRuntime = null
## NpcBase instance id -> stimulus id (registered by this service).
var _by_npc: Dictionary[int, int] = {}


func _ready() -> void:
	_runtime = HeistRuntime.of(self)
	EventBus.npc_alert_state_changed.connect(_on_alert_state_changed)


func _exit_tree() -> void:
	if EventBus.npc_alert_state_changed.is_connected(_on_alert_state_changed):
		EventBus.npc_alert_state_changed.disconnect(_on_alert_state_changed)


## Stimulus id this service registered for `npc` (0 = none).
func stimulus_of(npc: Node) -> int:
	return _by_npc.get(npc.get_instance_id(), 0) if npc != null else 0


func _on_alert_state_changed(npc_id: int, _old_state: int, new_state: int) -> void:
	if not Net.is_authority():
		return
	var npc: NpcBase = Ids.lookup(npc_id) as NpcBase
	if npc == null or npc.role == &"civilian":
		return
	if _runtime != null and not _runtime.is_ancestor_of(npc):
		return
	var key: int = npc.get_instance_id()
	if RESTRAINED_STATES.has(new_state) and npc.alive:
		if _by_npc.has(key) or _has_foreign(npc):
			return
		var st: StealthDirector = _stealth()
		if st != null:
			_by_npc[key] = st.register_stimulus(npc, KIND)
	elif _by_npc.has(key):
		var st2: StealthDirector = _stealth()
		if st2 != null:
			st2.unregister_stimulus(_by_npc[key])
		_by_npc.erase(key)


func _has_foreign(npc: Node) -> bool:
	var st: StealthDirector = _stealth()
	if st == null:
		return false
	for s: Dictionary in st.stimuli():
		if s.get("source") == npc and StringName(s.get("kind", &"")) == KIND:
			return true
	return false


func _stealth() -> StealthDirector:
	return _runtime.stealth if _runtime != null else null
