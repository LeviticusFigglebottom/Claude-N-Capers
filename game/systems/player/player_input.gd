## Local human input -> CrewIntent (crew_intent.md). Owner: ENV A.
## The ONLY place raw `Input` is read for gameplay. Added by CrewManager under the local
## player's CrewController on every peer. Integration-test bot intents (HeistRuntime) take
## precedence over this node while held.
class_name PlayerInput
extends Node

## Default bindings, registered at runtime when project.godot has no such action (QA-4).
const DEFAULT_BINDINGS: Dictionary = {
	&"move_forward": KEY_W, &"move_back": KEY_S, &"move_left": KEY_A, &"move_right": KEY_D,
	&"sprint": KEY_SHIFT, &"crouch": KEY_CTRL, &"jump": KEY_SPACE, &"interact": KEY_F,
	&"reload": KEY_R, &"shout": KEY_E, &"melee": KEY_V, &"throw_item": KEY_G, &"deploy": KEY_4,
	&"mask_up": KEY_G, &"slot_primary": KEY_1, &"slot_secondary": KEY_2, &"drop_bag": KEY_X,
}
const MOUSE_BINDINGS: Dictionary = {&"fire": MOUSE_BUTTON_LEFT, &"aim": MOUSE_BUTTON_RIGHT}

@export var mouse_sensitivity: float = 0.0025

var enabled: bool = true
var _yaw: float = 0.0
var _pitch: float = 0.0
var _crew: CrewController = null


func _ready() -> void:
	_crew = get_parent() as CrewController
	if _crew != null:
		_yaw = _crew.look_yaw
	ensure_actions()


static func ensure_actions() -> void:
	for a: StringName in DEFAULT_BINDINGS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = DEFAULT_BINDINGS[a]
			InputMap.action_add_event(a, ev)
	for a: StringName in MOUSE_BINDINGS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var mb: InputEventMouseButton = InputEventMouseButton.new()
			mb.button_index = MOUSE_BINDINGS[a]
			InputMap.action_add_event(a, mb)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= mm.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - mm.relative.y * mouse_sensitivity, -deg_to_rad(89.0), deg_to_rad(89.0))


func _physics_process(_delta: float) -> void:
	if not enabled or _crew == null:
		return
	var rt: HeistRuntime = HeistRuntime.of(_crew)
	if rt != null and rt.has_bot_intent(_crew.slot):
		return
	_crew.apply_intent(build_intent())


func build_intent() -> CrewIntent:
	var i: CrewIntent = CrewIntent.new()
	i.move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	i.look_yaw = _yaw
	i.look_pitch = _pitch
	i.sprint = Input.is_action_pressed(&"sprint")
	i.crouch = Input.is_action_pressed(&"crouch")
	i.jump = Input.is_action_pressed(&"jump")
	i.fire = Input.is_action_pressed(&"fire")
	i.aim = Input.is_action_pressed(&"aim")
	i.reload = Input.is_action_pressed(&"reload")
	i.interact = Input.is_action_pressed(&"interact")
	i.shout = Input.is_action_pressed(&"shout")
	i.melee = Input.is_action_pressed(&"melee")
	i.throw_item = Input.is_action_pressed(&"throw_item")
	i.deploy = Input.is_action_pressed(&"deploy")
	i.mask_up = Input.is_action_pressed(&"mask_up")
	i.drop_bag = Input.is_action_just_pressed(&"drop_bag")
	i.throw_bag = Input.is_action_pressed(&"drop_bag") and Input.is_action_pressed(&"aim")
	if Input.is_action_just_pressed(&"slot_primary"):
		i.weapon_slot = Enums.WeaponSlot.PRIMARY
	elif Input.is_action_just_pressed(&"slot_secondary"):
		i.weapon_slot = Enums.WeaponSlot.SECONDARY
	return i
