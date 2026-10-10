## Main menu: Safehouse (the hub, B4-07), Firing Range, Settings (stub), Quit. Owner: ENV B.
## Shows the profile's level and money. Signals are handled by MenuFlow.
class_name MainMenu
extends UiScreen

signal safehouse_requested()
signal firing_range_requested()
signal settings_requested()
signal quit_requested()

var safehouse_button: Button
var range_button: Button
var settings_button: Button
var quit_button: Button
var profile_label: Label


func build_ui() -> void:
	var root: VBoxContainer = UiBuild.vbox(16)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	UiBuild.screen_margin(self, root)
	var header: HBoxContainer = UiBuild.hbox(20)
	header.add_child(UiAccent.strip(UiAccent.table().fallback, 6.0))
	var titles: VBoxContainer = UiBuild.vbox(4)
	titles.add_child(UiBuild.label(&"ui.menu.title", UiBuild.HEADER))
	profile_label = UiBuild.label(&"", UiBuild.DIM)
	titles.add_child(profile_label)
	header.add_child(titles)
	root.add_child(header)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	root.add_child(spacer)
	safehouse_button = UiBuild.button(&"ui.menu.safehouse")
	range_button = UiBuild.button(&"ui.menu.firing_range")
	settings_button = UiBuild.button(&"ui.menu.options")
	quit_button = UiBuild.button(&"ui.menu.quit")
	for b: Button in [safehouse_button, range_button, settings_button, quit_button]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		root.add_child(b)
		focus_chain.append(b)
	safehouse_button.pressed.connect(safehouse_requested.emit)
	range_button.pressed.connect(firing_range_requested.emit)
	settings_button.pressed.connect(settings_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)
	back_requested.connect(quit_button.grab_focus)
	refresh_profile()


func refresh_profile(profile: PlayerProfile = null) -> void:
	var p: PlayerProfile = profile if profile != null else SaveService.load_profile()
	profile_label.text = "%s   %s   %s" % [
		UiText.t(&"ui.menu.level", {"level": p.level}),
		UiText.t(&"ui.menu.spending", {"amount": UiText.money(p.cash)}),
		UiText.t(&"ui.menu.stash", {"amount": UiText.money(p.stash)}),
	]
