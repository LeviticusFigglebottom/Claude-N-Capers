## PO-4 first-time guidance (docs/design/ui/style.md §8): ONE contextual control hint at the bottom
## centre, picked from real state, most urgent first:
##   1. the mouse is not captured during play -> "Click to resume" (the game ignores look input);
##   2. casing (player_mode &"casing")        -> "Hold [G] to mask up";
##   3. carrying a bag while masked            -> "Press [key] to throw the bag".
## Nothing otherwise. The key caps follow the last device (InteractionPanel.action_key_text).
## `capture_probe` returns whether the mouse counts as captured; the default asks MouseCapture
## (input_focus.md 1.1): "Click to resume" exactly when gameplay wants the cursor but does not hold it
## (no menu release, OS refused or focus came back). Owner: ENV B.
class_name HintStrip
extends HudWidget

const MASK_ACTION: StringName = &"mask_up"
const THROW_ACTION: StringName = &"drop_bag"

var prompt: KeyPrompt
## Current hint id: &"" / &"resume" / &"mask_up" / &"throw_bag" (tests).
var hint: StringName = &""
var capture_probe: Callable = func() -> bool:
	return MouseCapture.is_captured() or not MouseCapture.wants_capture()
var _captured: bool = true
var _sounded_hint: StringName = &""


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
	var was: bool = visible
	visible = hint != &""
	if hint != &"" and hint != _sounded_hint:
		UiSfx.play(UiSfx.HINT)  # D-090: a new hint appears
	_sounded_hint = hint
	if visible and not was and is_inside_tree() and UiTokens.motion_ok():
		modulate.a = 0.0  # PO-4 motion: a new hint fades in
		create_tween().tween_property(self, ^"modulate:a", 1.0, UiTokens.T_BASE).set_ease(Tween.EASE_OUT)
