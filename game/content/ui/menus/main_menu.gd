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


## PO-4 layout (docs/design/ui/style.md): the wordmark and tagline over a short list of big caps
## entries on the left third, the crew's level / money as caption + value pairs along the bottom.
func build_ui() -> void:
	var root: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	UiBuild.screen_margin(self, root, UiTokens.MARGIN + UiTokens.S5)
	var title: Label = UiBuild.label(&"ui.menu.title", UiBuild.DISPLAY)
	title.uppercase = true
	root.add_child(title)
	var rule: ColorRect = ColorRect.new()
	rule.color = UiTokens.BRASS
	rule.custom_minimum_size = Vector2(120, 4)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rule)
	root.add_child(UiBuild.caption(&"ui.menu.tagline"))
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, UiTokens.S6)
	root.add_child(spacer)
	safehouse_button = UiBuild.button(&"ui.menu.safehouse")
	range_button = UiBuild.button(&"ui.menu.firing_range")
	settings_button = UiBuild.button(&"ui.menu.options")
	quit_button = UiBuild.button(&"ui.menu.quit")
	for b: Button in [safehouse_button, range_button, settings_button, quit_button]:
		b.theme_type_variation = UiBuild.MENU_ITEM
		b.text = b.text.to_upper()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(440, 0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		root.add_child(b)
		focus_chain.append(b)
	safehouse_button.add_theme_color_override(&"font_color", UiTokens.PAPER)
	var foot: Control = Control.new()
	foot.custom_minimum_size = Vector2(0, UiTokens.S7)
	root.add_child(foot)
	profile_label = UiBuild.label(&"", UiBuild.DIM)
	root.add_child(profile_label)
	safehouse_button.pressed.connect(safehouse_requested.emit)
	range_button.pressed.connect(firing_range_requested.emit)
	settings_button.pressed.connect(settings_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)
	back_requested.connect(quit_button.grab_focus)
	refresh_profile()


func refresh_profile(profile: PlayerProfile = null) -> void:
	var p: PlayerProfile = profile if profile != null else SaveService.load_profile()
	profile_label.text = "%s   ·   %s   ·   %s" % [
		UiText.t(&"ui.menu.level", {"level": p.level}),
		UiText.t(&"ui.menu.spending", {"amount": UiText.money(p.cash)}),
		UiText.t(&"ui.menu.stash", {"amount": UiText.money(p.stash)}),
	]
