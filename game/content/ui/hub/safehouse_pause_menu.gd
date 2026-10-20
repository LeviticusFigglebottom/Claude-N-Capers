## 3D safehouse pause menu (B6-06, QC-49). Owner: ENV B. Opened by Esc / `pause` while walking
## (SafehouseHost.open_pause); the walker stays paused behind it. Resume (and Esc / gamepad B) ->
## back_requested (MenuFlow.show_hub resumes walking); Quick Stations jump straight to any station's
## screen (station_requested(id) -> MenuFlow.open_station; its Back returns to walking on the spot);
## Options, Achievements, Bot Crew (PO-19) and Main Menu (leaves the safehouse) as on the 2D hub's profile panel.
class_name SafehousePauseMenu
extends UiScreen

signal station_requested(station_id: StringName)
signal options_requested()
signal achievements_requested()
## PO-19: the Bot Crew screen.
signal crew_requested()
signal main_menu_requested()

## Quick station list (MenuFlow passes its HubStationList; default: data/ui/hub_stations.tres).
var stations: HubStationList = null
var resume_button: Button
var options_button: Button
var achievements_button: Button
var crew_button: Button
var main_menu_button: Button
## Station id -> its quick-station Button.
var station_buttons: Dictionary = {}


func build_ui() -> void:
	if stations == null:
		stations = HubStationList.load_default()
	var v: VBoxContainer = UiBuild.vbox(14)
	v.custom_minimum_size = Vector2(620, 0)
	v.add_child(UiBuild.label(&"ui.hub.pause.title", UiBuild.HEADER))
	resume_button = UiBuild.primary(UiBuild.button(&"ui.hub.pause.resume"))
	resume_button.pressed.connect(back_requested.emit)
	v.add_child(resume_button)
	focus_chain.append(resume_button)
	v.add_child(UiBuild.label(&"ui.hub.pause.quick_stations", UiBuild.DIM))
	var grid: GridContainer = GridContainer.new()
	grid.name = "QuickStations"
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	v.add_child(grid)
	for s: HubStation in stations.stations:
		var b: Button = UiBuild.button(s.title_key)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = UiText.t(s.desc_key)
		b.pressed.connect(station_requested.emit.bind(s.id))
		grid.add_child(b)
		station_buttons[s.id] = b
		focus_chain.append(b)
	v.add_child(HSeparator.new())
	options_button = UiBuild.button(&"ui.menu.options")
	options_button.pressed.connect(options_requested.emit)
	achievements_button = UiBuild.button(&"ui.hub.achievements")
	achievements_button.pressed.connect(achievements_requested.emit)
	crew_button = UiBuild.button(&"ui.hub.crew")
	crew_button.pressed.connect(crew_requested.emit)
	main_menu_button = UiBuild.button(&"ui.hub.main_menu")
	main_menu_button.pressed.connect(main_menu_requested.emit)
	for b: Button in [options_button, achievements_button, crew_button, main_menu_button]:
		v.add_child(b)
		focus_chain.append(b)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(UiBuild.panel(v))
	add_child(center)


## The quick-station button for `id` (null when unknown).
func station_button(id: StringName) -> Button:
	return station_buttons.get(id, null) as Button
