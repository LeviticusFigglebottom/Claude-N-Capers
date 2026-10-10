## Local human input -> CrewIntent (crew_intent.md). Owner: ENV A.
## The ONLY place raw `Input` is read for gameplay. Added by HeistRuntime under the local
## player's CrewController on every peer. Integration-test bot intents (HeistRuntime) take
## precedence over this node while held. Actions are defined in project.godot (D-025, QA-4).
##
## Contextual keys (PD2 style):
##   F (`interact` / `shout`): hold to interact when an interactable is aimed at, otherwise a
##     press is a shout (intimidate / mark).
##   G (`mask_up` / `throw_item` / `drop_bag`): hold to mask up while unmasked; while masked and
##     carrying a bag a press throws the bag; otherwise a press throws the throwable.
class_name PlayerInput
extends Node

@export var mouse_sensitivity: float = 0.0025

var enabled: bool = true
var _yaw: float = 0.0
var _pitch: float = 0.0
var _crew: CrewController = null
## Slot to restore when `swap_weapon` toggles.
var _last_slot: int = Enums.WeaponSlot.SECONDARY


func _ready() -> void:
	_crew = get_parent() as CrewController
	if _crew != null:
		_yaw = _crew.look_yaw


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
	_crew.apply_intent(build_intent(rt))


func build_intent(rt: HeistRuntime) -> CrewIntent:
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
	i.melee = Input.is_action_pressed(&"melee")
	i.deploy = Input.is_action_pressed(&"deploy")
	# F: interact when aiming at something usable, else shout.
	var isys: InteractionSystem = rt.interaction if rt != null else null
	var aimed: bool = isys != null and (isys.aimed_component(_crew) != null or not isys.session(_crew.slot).is_empty())
	var f_held: bool = Input.is_action_pressed(&"interact") or Input.is_action_pressed(&"shout")
	i.interact = f_held and aimed
	i.shout = not i.interact and (Input.is_action_just_pressed(&"shout") or Input.is_action_just_pressed(&"interact"))
	# G: mask up (hold) / throw bag / throwable.
	var g_held: bool = Input.is_action_pressed(&"mask_up")
	var g_pressed: bool = Input.is_action_just_pressed(&"mask_up") or Input.is_action_just_pressed(&"throw_item") \
		or Input.is_action_just_pressed(&"drop_bag")
	if not _crew.masked:
		i.mask_up = g_held
	elif _crew.is_carrying_bag():
		i.throw_bag = g_pressed
	else:
		i.throw_item = g_pressed
	if Input.is_action_just_pressed(&"slot_primary"):
		i.weapon_slot = Enums.WeaponSlot.PRIMARY
	elif Input.is_action_just_pressed(&"slot_secondary"):
		i.weapon_slot = Enums.WeaponSlot.SECONDARY
	elif Input.is_action_just_pressed(&"swap_weapon"):
		_last_slot = Enums.WeaponSlot.PRIMARY if _last_slot == Enums.WeaponSlot.SECONDARY else Enums.WeaponSlot.SECONDARY
		i.weapon_slot = _last_slot
	return i
