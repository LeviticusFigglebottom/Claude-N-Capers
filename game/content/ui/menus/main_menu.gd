## Main menu: Play solo, Firing Range (coming soon), Settings (stub), Quit. Owner: ENV B.
## Shows the profile's level and money. Signals are handled by MenuFlow.
class_name MainMenu
extends UiScreen

signal play_solo_requested()
signal firing_range_requested()
signal settings_requested()
signal quit_requested()

var play_button: Button
var range_button: Button
var settings_button: Button
var quit_button: Button
var profile_label: Label


func build_ui() -> void:
	var root: VBoxContainer = UiBuild.vbox(16)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	UiBuild.screen_margin(self, root)
	root.add_child(UiBuild.label(&"ui.menu.title", UiBuild.HEADER))
	profile_label = UiBuild.label(&"", UiBuild.DIM)
	root.add_child(profile_label)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	root.add_child(spacer)
	play_button = UiBuild.button(&"ui.menu.solo")
	range_button = UiBuild.button(&"ui.menu.firing_range_soon")
	range_button.disabled = true
	range_button.tooltip_text = UiText.t(&"ui.menu.coming_soon")
	settings_button = UiBuild.button(&"ui.menu.options")
	quit_button = UiBuild.button(&"ui.menu.quit")
	for b: Button in [play_button, range_button, settings_button, quit_button]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		root.add_child(b)
		focus_chain.append(b)
	play_button.pressed.connect(play_solo_requested.emit)
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
