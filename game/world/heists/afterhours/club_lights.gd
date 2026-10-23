## Afterhours `Lighting/ClubLights` (afterhours.md §Audio/lighting, the hall's two states). Owner: ENV C.
## Children (built by the generator, greybox/build_greybox.gd _build_club_lights): `Club*` coloured OmniLights over the
## dance floor and the stage (state &"club", the stealth default) and `Work*` white work lights (state &"house", loud).
## ENV A's mission calls set_state(&"house") on the alarm (it finds this node by name); the mission runs on the server
## only, so every peer also brings the house up on its own EventBus.alarm_raised (presentation only, idempotent).
## G1 greybox: a few unshadowed lights, no fixtures; the lighting lane (moving heads, mirror ball, DYNAMIC GI) replaces
## the children, not this API.
class_name ClubLights
extends Node3D

const CLUB: StringName = &"club"
const HOUSE: StringName = &"house"
const CLUB_PREFIX: String = "Club"
const WORK_PREFIX: String = "Work"

## The current state (&"club" or &"house").
@export var state: StringName = CLUB


func _ready() -> void:
	_apply()
	if not EventBus.alarm_raised.is_connected(_on_alarm_raised):
		EventBus.alarm_raised.connect(_on_alarm_raised)


## &"club": the coloured lights on, the work lights off; &"house": the reverse. Unknown states are ignored.
func set_state(new_state: StringName) -> void:
	if new_state != CLUB and new_state != HOUSE:
		push_warning("ClubLights: unknown state %s" % new_state)
		return
	state = new_state
	_apply()


func _apply() -> void:
	for c: Node in get_children():
		var l: Light3D = c as Light3D
		if l == null:
			continue
		if String(l.name).begins_with(CLUB_PREFIX):
			l.visible = state == CLUB
		elif String(l.name).begins_with(WORK_PREFIX):
			l.visible = state == HOUSE


func _on_alarm_raised(_reason: StringName, _source_net_id: int) -> void:
	set_state(HOUSE)
