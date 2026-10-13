## PO-4 first-time guidance (docs/design/ui/style.md §8): ONE contextual control hint at the bottom
## centre, picked from real state, most urgent first:
##   1. the mouse is not captured during play -> "Click to resume" (the game ignores look input);
##   2. casing (player_mode &"casing")        -> "Hold [G] to mask up";
##   3. carrying a bag while masked            -> "Press [key] to throw the bag".
## Nothing otherwise. The key caps follow the last device (InteractionPanel.action_key_text).
## `capture_probe` returns whether the mouse counts as captured; the default reads Input.mouse_mode
## (true on headless, where the mouse is never captured). Owner: ENV B.
class_name HintStrip
extends HudWidget

const MASK_ACTION: StringName = &"mask_up"
const THROW_ACTION: StringName = &"drop_bag"

var prompt: KeyPrompt
## Current hint id: &"" / &"resume" / &"mask_up" / &"throw_bag" (tests).
var hint: StringName = &""
var capture_probe: Callable = func() -> bool:
	return DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
var _captured: bool = true


func build() -> void:
	var p: PanelContainer = UiBuild.panel(VBoxContainer.new(), UiBuild.HUD_PANEL)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(p)
	prompt = KeyPrompt.new(UiTokens.FONT_BODY)
	p.get_child(0).add_child(prompt)


func watched_signals() -> Array[StringName]:
	return [&"player_mode_changed", &"masked_changed", &"carried_bag_changed"]


func _process(_delta: float) -> void:
	var c: bool = bool(capture_probe.call())
	if c != _captured:
		_captured = c
		refresh()


func refresh() -> void:
	if prompt == null:
		return
	var mode: StringName = player_mode()
	var bag: StringName = StringName((prop(&"carried_bag", {}) as Dictionary).get("loot_id", &""))
	if model != null and not _captured:
		hint = &"resume"
		prompt.set_line(UiText.t(&"ui.hud.hint.click_resume"), "")
	elif mode == &"casing":
		hint = &"mask_up"
		prompt.set_prompt(&"ui.hud.mask_up_hint", {}, InteractionPanel.action_key_text(MASK_ACTION))
	elif mode == &"masked" and bag != &"" and InputMap.has_action(THROW_ACTION):
		hint = &"throw_bag"
		prompt.set_prompt(&"ui.prompt.throw_bag", {}, InteractionPanel.action_key_text(THROW_ACTION))
	else:
		hint = &""
	visible = hint != &""
