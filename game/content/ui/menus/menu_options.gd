## Opens / closes the options screen for MenuFlow (B5-01). Owner: ENV B. A child node of MenuFlow
## (`MenuFlow.options`), split out to keep MenuFlow's API small.
## Menus: open() shows OptionsScreen as a MenuFlow screen (main menu Options, hub profile panel
## Options); Back frees it and returns to the screen it came from (the hub is refreshed).
## Heist: MenuFlow sets `heist_layer` (the HUD / payday CanvasLayer) and `heist_payday`. PO-4: the
## `pause` action opens the PauseMenu (Resume / Options / Leave Heist) over the HUD while the game keeps
## running (PD2 has no pause); the local crew member's input is paused (CrewInput holder &"options")
## and the mouse released. Options from the pause menu (open_in_heist()) shows the screen over it and
## Back returns to the pause menu; Resume / Esc / pause again closes everything and restores both.
class_name MenuOptions
extends Node

var flow: MenuFlow
## Options screen while open from the menus, else null.
var screen: OptionsScreen = null
## Options screen while open over the HUD, else null.
var heist_screen: OptionsScreen = null
## PO-4 in-heist pause menu while open, else null.
var pause_menu: PauseMenu = null
## Set by MenuFlow while a heist UI layer exists (null otherwise).
var heist_layer: CanvasLayer = null
var heist_payday: Control = null


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


## The in-heist pause menu (pause action). Returns it, or null without a heist layer.
func open_pause() -> PauseMenu:
	if pause_menu != null and is_instance_valid(pause_menu):
		return pause_menu
	if heist_layer == null or not is_instance_valid(heist_layer):
		return null
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.resume_requested.connect(close_pause)
	pause_menu.options_requested.connect(open_in_heist)
	pause_menu.leave_requested.connect(func() -> void: flow.call(&"_request_leave_heist"))
	heist_layer.add_child(pause_menu)
	pause_menu.set_job(job_snapshot())
	_hold(true)
	return pause_menu


## Lead queue (a): what the pause menu's job card shows, read from the running HUD (heist, current
## objective, the Tab sheet's loot tally) and MenuFlow (difficulty). {} when there is no HUD.
func job_snapshot() -> Dictionary:
	var hud: Hud = null
	for c: Node in heist_layer.get_children():
		if c is Hud:
			hud = c as Hud
	if hud == null:
		return {}
	var info: Dictionary = {"heist_id": hud.heist_id, "difficulty": int(flow.get(&"_difficulty")) if flow != null else 0}
	if hud.objectives != null and hud.objectives.list_box.get_child_count() > 0:
		info["objective"] = ObjectivesPanel.objective_text(_current_objective(hud), hud.objectives.secured_count)
	var bags: int = 0
	var value: int = 0
	if hud.scoreboard != null:
		for e: Variant in hud.scoreboard.loot_secured.values():
			bags += int((e as Dictionary)["count"])
			value += int((e as Dictionary)["value"])
		value += hud.scoreboard.small_loot_value
	info["bags"] = bags
	info["loot_value"] = value
	return info


static func _current_objective(hud: Hud) -> Dictionary:
	var id: StringName = hud.objectives.shown_id
	for o: Dictionary in hud.objectives.prop(&"objectives", []) as Array:
		if StringName(o.get("id", &"")) == id:
			return o
	return {}


## Closes the pause menu and any Options over it; input and cursor come back.
func close_pause() -> void:
	if pause_menu == null:
		close_in_heist()
		return
	if heist_screen != null and is_instance_valid(heist_screen):
		heist_screen.queue_free()
	heist_screen = null
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu.queue_free()
	pause_menu = null
	_hold(false)


## Options over the HUD (from the pause menu, which hides meanwhile; standalone when called directly).
func open_in_heist() -> OptionsScreen:
	if heist_screen != null and is_instance_valid(heist_screen):
		return heist_screen
	if heist_layer == null or not is_instance_valid(heist_layer):
		return null
	var from_pause: bool = pause_menu != null and is_instance_valid(pause_menu)
	heist_screen = flow.OPTIONS_SCENE.instantiate() as OptionsScreen
	heist_screen.in_heist = not from_pause  # the pause menu has its own Leave Heist
	heist_screen.back_requested.connect(close_in_heist)
	heist_screen.leave_heist_requested.connect(flow.call.bind(&"_leave_heist"))
	heist_layer.add_child(heist_screen)
	if from_pause:
		pause_menu.visible = false
	else:
		_hold(true)
	return heist_screen


## Back from Options: to the pause menu when it opened Options, else back to play.
func close_in_heist() -> void:
	if heist_screen == null:
		return
	if is_instance_valid(heist_screen):
		heist_screen.queue_free()
	heist_screen = null
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu.visible = true
		pause_menu.focus_default()
		return
	_hold(false)


## Pauses the local crew's input and holds the cursor (input_focus.md 1.1: MouseCapture &"pause").
func _hold(on: bool) -> void:
	_set_local_input_paused(on)
	if on:
		MouseCapture.push_release(&"pause")
	else:
		MouseCapture.pop_release(&"pause")


func _exit_tree() -> void:
	MouseCapture.pop_release(&"pause")


func _unhandled_input(event: InputEvent) -> void:
	if heist_layer == null or not event.is_action_pressed(&"pause"):
		return
	if heist_payday != null and is_instance_valid(heist_payday) and heist_payday.visible:
		return
	if heist_screen != null:
		return  # Options handles its own Back / Esc
	get_viewport().set_input_as_handled()
	if pause_menu != null:
		close_pause()
	else:
		open_pause()


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


## Through CrewInput (holder &"options"): another overlay's pause (chat, drop-in) is kept.
func _set_local_input_paused(paused: bool) -> void:
	CrewInput.set_paused(get_tree(), &"options", paused, Net.local_slot())
