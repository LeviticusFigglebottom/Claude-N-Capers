## Main menu: Safehouse (the hub, B4-07), Firing Range, Settings (stub), Quit. Owner: ENV B.
## Shows the profile's level and money. Signals are handled by MenuFlow.
class_name MainMenu
extends UiScreen

signal safehouse_requested()
signal firing_range_requested()
signal settings_requested()
signal quit_requested()
## Lead: relaunch the last job (QuickPlay).
signal continue_requested()

var safehouse_button: Button
var range_button: Button
var settings_button: Button
var quit_button: Button
## Quick Play: "CONTINUE · <heist> · <difficulty>" above Safehouse, hidden without a playable last job.
var continue_button: Button
var profile_label: Label
## PO-4 (lead note 4): the equipped mask turning slowly on the right half, the heist icon of the game.
var hero: MaskPreview
var hero_name: Label


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
	continue_button = UiBuild.button(&"ui.menu.continue")
	continue_button.pressed.connect(continue_requested.emit)
	safehouse_button = UiBuild.button(&"ui.menu.safehouse")
	range_button = UiBuild.button(&"ui.menu.firing_range")
	settings_button = UiBuild.button(&"ui.menu.options")
	quit_button = UiBuild.button(&"ui.menu.quit")
	for b: Button in [continue_button, safehouse_button, range_button, settings_button, quit_button]:
		b.theme_type_variation = UiBuild.MENU_ITEM  # D-090: focus + confirm cues come with UiBuild.button
		b.text = b.text.to_upper()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(440, 0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		root.add_child(b)
		focus_chain.append(b)
	safehouse_button.add_theme_color_override(&"font_color", UiTokens.PAPER)
	continue_button.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	var foot: Control = Control.new()
	foot.custom_minimum_size = Vector2(0, UiTokens.S7)
	root.add_child(foot)
	profile_label = UiBuild.label(&"", UiBuild.DIM)
	root.add_child(profile_label)
	_build_hero()
	safehouse_button.pressed.connect(safehouse_requested.emit)
	range_button.pressed.connect(firing_range_requested.emit)
	settings_button.pressed.connect(settings_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)
	back_requested.connect(quit_button.grab_focus)
	refresh_profile()


func _build_hero() -> void:
	hero = MaskPreview.new()
	hero.name = "Hero"
	hero.focus_mode = Control.FOCUS_NONE
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.anchor_left = 0.42
	hero.anchor_right = 1.0
	hero.anchor_bottom = 1.0
	hero.offset_top = UiTokens.MARGIN
	hero.offset_bottom = -UiTokens.MARGIN * 2
	hero.offset_right = -UiTokens.MARGIN
	hero.viewport.transparent_bg = true  # the Case File backdrop shows behind the mask
	for n: Node in hero.viewport.get_children():
		if n is WorldEnvironment:
			(n as WorldEnvironment).environment.background_mode = Environment.BG_CLEAR_COLOR
	add_child(hero)
	hero_name = UiBuild.caption()
	hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_name.anchor_left = 0.42
	hero_name.anchor_right = 1.0
	hero_name.anchor_top = 1.0
	hero_name.anchor_bottom = 1.0
	hero_name.offset_top = -UiTokens.MARGIN * 2
	hero_name.offset_bottom = -UiTokens.MARGIN - UiTokens.S5
	hero_name.offset_right = -UiTokens.MARGIN
	add_child(hero_name)


func refresh_profile(profile: PlayerProfile = null) -> void:
	var p: PlayerProfile = profile if profile != null else SaveService.load_profile()
	if hero != null:
		hero.show_def(MaskCatalog.resolve(p.loadout.mask, p))
		hero_name.text = MaskCatalog.display_name(p.loadout.mask)
	var job: Dictionary = QuickPlay.last(p)
	continue_button.visible = not job.is_empty()
	if not job.is_empty():
		continue_button.text = QuickPlay.label(job).to_upper()
	# A hidden Continue must not stay in the up / down links (gate82 trap class, test_menu_reach).
	var shown: Array[Control] = []
	for c: Control in focus_chain:
		if c.visible:
			shown.append(c)
	UiNav.chain_vertical(shown)
	profile_label.text = "%s   ·   %s   ·   %s" % [
		UiText.t(&"ui.menu.level", {"level": p.level}),
		UiText.t(&"ui.menu.spending", {"amount": UiText.money(p.cash)}),
		UiText.t(&"ui.menu.stash", {"amount": UiText.money(p.stash)}),
	]
