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
## G3: the back-of-house dressing these lights must not reach through the walls (greybox/ah_gi.gd club_skip). Their
## meshes sit inside prop instances, whose layer overrides a saved scene drops, so _ready moves them from render layer 1
## to `skip_layer`, which every child light's light_cull_mask leaves out (the finishes are moved at build time).
@export var skip_roots: Array[NodePath] = []
@export var skip_layer: int = 0


func _ready() -> void:
	_apply()
	_skip_layers()
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


func _skip_layers() -> void:
	if skip_layer == 0:
		return
	for np: NodePath in skip_roots:
		var root: Node = get_node_or_null(np)
		if root == null:
			continue
		for g: Node in root.find_children("*", "GeometryInstance3D", true, false):
			var gi: GeometryInstance3D = g as GeometryInstance3D
			gi.layers = (gi.layers & ~1) | skip_layer


func _on_alarm_raised(_reason: StringName, _source_net_id: int) -> void:
	set_state(HOUSE)
