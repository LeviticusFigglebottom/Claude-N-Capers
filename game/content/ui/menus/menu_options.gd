## Opens / closes the options screen for MenuFlow (B5-01). Owner: ENV B. A child node of MenuFlow
## (`MenuFlow.options`), split out to keep MenuFlow's API small.
## Menus: open() shows OptionsScreen as a MenuFlow screen (main menu Options, hub profile panel
## Options); Back frees it and returns to the screen it came from (the hub is refreshed).
## Heist: MenuFlow sets `heist_layer` (the HUD / payday CanvasLayer) and `heist_payday`; the `pause`
## action (or open_in_heist()) shows the screen over the HUD while the game keeps running (PD2 has no
## pause); the local crew member's input is paused (CrewController.set_input_paused, found by group
## G.CREW + slot == Net.local_slot()) and the mouse released; Back / Esc closes it and restores both.
class_name MenuOptions
extends Node

var flow: MenuFlow
## Options screen while open from the menus, else null.
var screen: OptionsScreen = null
## Options screen while open over the HUD, else null.
var heist_screen: OptionsScreen = null
## Set by MenuFlow while a heist UI layer exists (null otherwise).
var heist_layer: CanvasLayer = null
var heist_payday: Control = null
var _mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


## Shows the options (over the HUD while a heist layer exists).
func open() -> OptionsScreen:
	if heist_layer != null and is_instance_valid(heist_layer):
		return open_in_heist()
	if screen != null and is_instance_valid(screen):
		flow.show_screen(screen)
		return screen
	var back_to: Control = flow.current
	var s: OptionsScreen = flow.OPTIONS_SCENE.instantiate() as OptionsScreen
	s.visible = false
	flow.add_child(s)
	s.back_requested.connect(_close_menu.bind(s, back_to))
	screen = s
	flow.show_screen(s)
	return s


func open_in_heist() -> OptionsScreen:
	if heist_screen != null and is_instance_valid(heist_screen):
		return heist_screen
	if heist_layer == null or not is_instance_valid(heist_layer):
		return null
	heist_screen = flow.OPTIONS_SCENE.instantiate() as OptionsScreen
	heist_screen.back_requested.connect(close_in_heist)
	heist_layer.add_child(heist_screen)
	_set_local_input_paused(true)
	if DisplayServer.get_name() != "headless":
		_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return heist_screen


func close_in_heist() -> void:
	if heist_screen == null:
		return
	if is_instance_valid(heist_screen):
		heist_screen.queue_free()
	heist_screen = null
	_set_local_input_paused(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = _mouse_mode


func _unhandled_input(event: InputEvent) -> void:
	if heist_layer == null or not event.is_action_pressed(&"pause"):
		return
	if heist_screen != null or (heist_payday != null and is_instance_valid(heist_payday) and heist_payday.visible):
		return
	get_viewport().set_input_as_handled()
	open_in_heist()


func _close_menu(s: OptionsScreen, back_to: Control) -> void:
	if is_instance_valid(s):
		flow.remove_child(s)
		s.queue_free()
	screen = null
	if back_to == flow.hub:
		flow.show_hub()
	elif back_to != null and is_instance_valid(back_to):
		flow.show_screen(back_to)
	else:
		flow.show_home()


func _set_local_input_paused(paused: bool) -> void:
	for n: Node in get_tree().get_nodes_in_group(G.CREW):
		var slot: Variant = n.get(&"slot")
		if slot is int and int(slot) == Net.local_slot() and n.has_method(&"set_input_paused"):
			n.call(&"set_input_paused", paused)
