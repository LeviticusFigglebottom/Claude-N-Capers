## Afterhours `Audio/ClubSound` (afterhours.md §Audio/lighting): the club's own sound in the hall (G6). Owner: ENV C.
## Children (CueEmitters built by the generator, greybox/build_greybox.gd _build_audio): the autoplaying beds
## BED_NAMES (cue.amb_afterhours_club_music, cue.amb_afterhours_club), POWER_DOWN (cue.club_power_down, one-shot) and
## STAMPEDE (cue.crowd_stampede, the loop). ENV A's mission calls cut() on the alarm (it finds this node by name); the
## mission runs on the server only, so every peer also cuts on its own EventBus.alarm_raised (presentation only,
## idempotent). The cue defs are ENV B's (cues.tres); an id missing there plays CueEmitter's placeholder.
class_name ClubSound
extends Node3D

const BED_NAMES: Array[String] = ["BedClubMusic", "BedClub"]
const POWER_DOWN: String = "PowerDown"
const STAMPEDE: String = "Stampede"

## True once the music has been cut (the house is up).
var is_cut: bool = false


func _ready() -> void:
	if not EventBus.alarm_raised.is_connected(_on_alarm_raised):
		EventBus.alarm_raised.connect(_on_alarm_raised)


## Stops the club beds, plays the power-down one-shot and starts the stampede loop (all at the hall).
func cut() -> void:
	if is_cut:
		return
	is_cut = true
	for nm: String in BED_NAMES:
		_emit(nm, &"stop")
	_emit(POWER_DOWN, &"play")
	_emit(STAMPEDE, &"play")


## Stops the stampede loop (the last fleeing civilian has gone).
func stop_stampede() -> void:
	_emit(STAMPEDE, &"stop")


func _emit(child: String, method: StringName) -> void:
	var em: Node = get_node_or_null(child)
	if em != null and em.has_method(method):
		em.call(method)


func _on_alarm_raised(_reason: StringName, _source_net_id: int) -> void:
	cut()
