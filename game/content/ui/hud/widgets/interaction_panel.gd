## Interaction prompt (tr(text_key) with args), hold progress ring around the key cap and blocked reason (S9.1, S1.1).
## PO-4: the key is drawn as a key cap (KeyPrompt).
## The input key name is presentation (hud_model README): when the model's args carry no `key`,
## the first binding of the prompt's action (action_for: interact, or mask_up / drop_bag / shout) is filled in
## for the `{key}` placeholder.
class_name InteractionPanel
extends HudWidget

## The default InteractableComponent.prompt_key, and kinds whose verb string is not `ui.prompt.<kind>`.
const GENERIC_PROMPT: StringName = &"ui.prompt.interact"
const KIND_PROMPTS: Dictionary = {
	&"lockpick": &"ui.prompt.pick_lock", &"keycard": &"ui.prompt.use_keycard", &"use_keycard": &"ui.prompt.use_keycard",
	&"pick_up_keycard": &"ui.prompt.take_keycard", &"small_loot": &"ui.prompt.take_small_loot",
	&"drill": &"ui.prompt.place_drill", &"hack": &"ui.prompt.start_hack",
}
const INTERACT_ACTION: StringName = &"interact"
## D-115: prompts whose {key} is not the interact key (the input that does it). Any other prompt shows interact.
const PROMPT_ACTIONS: Dictionary = {&"ui.prompt.mask_up": &"mask_up", &"ui.prompt.throw_bag": &"drop_bag",
	&"ui.prompt.intimidate": &"shout"}

## D-082 fix: pad players saw keyboard keys ("Hold F") in prompts. Xbox-style names for the pad, as strings keys
## (lead r242 hard-coded string scan: "Back", "Start" and "D-pad Up" were literals).
const PAD_BUTTON_NAMES: Dictionary = {JOY_BUTTON_A: &"ui.key.pad.a", JOY_BUTTON_B: &"ui.key.pad.b",
	JOY_BUTTON_X: &"ui.key.pad.x", JOY_BUTTON_Y: &"ui.key.pad.y", JOY_BUTTON_LEFT_SHOULDER: &"ui.key.pad.lb",
	JOY_BUTTON_RIGHT_SHOULDER: &"ui.key.pad.rb", JOY_BUTTON_LEFT_STICK: &"ui.key.pad.ls",
	JOY_BUTTON_RIGHT_STICK: &"ui.key.pad.rs", JOY_BUTTON_BACK: &"ui.key.pad.back", JOY_BUTTON_START: &"ui.key.start",
	JOY_BUTTON_DPAD_UP: &"ui.key.pad.dpad_up", JOY_BUTTON_DPAD_DOWN: &"ui.key.pad.dpad_down",
	JOY_BUTTON_DPAD_LEFT: &"ui.key.pad.dpad_left", JOY_BUTTON_DPAD_RIGHT: &"ui.key.pad.dpad_right"}

## Mouse-bound actions (fire, aim) on the keyboard / mouse device: short names for a key cap.
const MOUSE_BUTTON_KEYS: Dictionary = {MOUSE_BUTTON_LEFT: &"ui.key.mouse_left",
	MOUSE_BUTTON_RIGHT: &"ui.key.mouse_right", MOUSE_BUTTON_MIDDLE: &"ui.key.mouse_middle"}

## True after the player's last input came from a gamepad (see note_input).
static var pad_active: bool = false

var prompt: KeyPrompt
## A ProgressRing (ProgressBar API) drawn around the key cap.
var progress_bar: ProgressBar
var blocked_label: Label
## r228: docked in the black scope margin, the prompt sits on a dark plate (Hud._avoid_scope sets it).
var plated: bool = false:
	set(v):
		if v != plated:
			plated = v
			queue_redraw()


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	prompt = KeyPrompt.new(UiTokens.FONT_LEAD)
	prompt.set_color(tweak.interaction_color)
	v.add_child(prompt)
	# Lead round 64: the hold progress is a ring around the key cap (PD2), not a bar under the line.
	progress_bar = ProgressRing.new()
	progress_bar.self_modulate = tweak.interaction_color
	prompt.cap.add_child(progress_bar)
	prompt.add_theme_constant_override(&"separation", UiTokens.S2 + int(ProgressRing.PAD + ProgressRing.WIDTH))  # room for the ring
	blocked_label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD))
	blocked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blocked_label.add_theme_color_override(&"font_color", tweak.low_health_color)
	v.add_child(blocked_label)


func watched_signals() -> Array[StringName]:
	return [&"interaction_changed"]


func refresh() -> void:
	var it: Dictionary = prop(&"interaction", {}) as Dictionary
	var key: StringName = prompt_key_for(StringName(it.get("text_key", &"")), StringName(it.get("kind", &"")))
	visible = key != &""
	if not visible:
		return
	var args: Dictionary = (it.get("args", {}) as Dictionary).duplicate()
	for a: Variant in args:  # D-157: a StringName strings key as an argument (the sentry's {mode}) is shown translated
		if args[a] is StringName and String(args[a]).begins_with("ui."):
			args[a] = UiText.t(args[a] as StringName)
	if not args.has("key"):
		args["key"] = action_key_text(action_for(key))
	if not args.has("mask_key"):
		args["mask_key"] = action_key_text(&"mask_up")  # PO-5.11: "Mask up first (hold G)"
	prompt.set_prompt(key, args)
	var p: float = float(it.get("progress", 0.0))
	progress_bar.visible = p > 0.0
	progress_bar.value = p
	var blocked: StringName = StringName(it.get("blocked_reason", &""))
	blocked_label.visible = blocked != &""
	blocked_label.text = UiText.t(blocked, args) if blocked != &"" else ""
	queue_redraw()


func _draw() -> void:
	if not plated or prompt == null:
		return
	var box: Control = prompt.get_parent() as Control
	var r: Rect2 = Rect2(box.position + prompt.position, prompt.size).grow(UiTokens.S2)
	if blocked_label.visible:
		r = r.merge(Rect2(box.position + blocked_label.position, blocked_label.size).grow(UiTokens.S2))
	draw_rect(r, Color(UiTokens.INK_0, 0.85))


## The input action whose key a prompt names ({key}): PROMPT_ACTIONS, else interact.
static func action_for(text_key: StringName) -> StringName:
	return PROMPT_ACTIONS.get(text_key, INTERACT_ACTION) as StringName


## P fresh-eyes #13: an interactable left on the generic "Hold {key} to interact" names its action from its
## kind (InteractableComponent.kind, carried in the model's interaction dict): the workshop door's lockpick
## reads "Hold F to pick the lock". A specific prompt_key always wins.
static func prompt_key_for(text_key: StringName, kind: StringName) -> StringName:
	if text_key != GENERIC_PROMPT or kind == &"":
		return text_key
	var k: StringName = StringName(KIND_PROMPTS.get(kind, StringName("ui.prompt.%s" % kind)))
	return k if StringTable.has(k) else text_key


## Name of the first binding of `action` for the device the player used last (pad button names while
## `pad_active`, else the keyboard key; falls back to the other device when one has no binding).
static func action_key_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	if pad_active:
		var p: String = pad_text(action)
		if p != "":
			return p
	for ev: InputEvent in InputMap.action_get_events(action):
		var k: InputEventKey = ev as InputEventKey
		if k != null:
			var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			return OS.get_keycode_string(code)
	for ev: InputEvent in InputMap.action_get_events(action):
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if mb != null and MOUSE_BUTTON_KEYS.has(int(mb.button_index)):
			return UiText.t(MOUSE_BUTTON_KEYS[int(mb.button_index)] as StringName)
	return pad_text(action)


static func pad_text(action: StringName) -> String:
	for ev: InputEvent in InputMap.action_get_events(action):
		var b: InputEventJoypadButton = ev as InputEventJoypadButton
		if b != null and PAD_BUTTON_NAMES.has(int(b.button_index)):
			return UiText.t(PAD_BUTTON_NAMES[int(b.button_index)] as StringName)
		var m: InputEventJoypadMotion = ev as InputEventJoypadMotion
		if m != null and m.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			return UiText.t(&"ui.key.pad.lt" if m.axis == JOY_AXIS_TRIGGER_LEFT else &"ui.key.pad.rt")
	return ""


## Tracks the last device: a pad button / stick past the deadzone -> pad, a key / mouse button -> keyboard.
## Returns true when it switched.
static func note_input(event: InputEvent) -> bool:
	var was: bool = pad_active
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		pad_active = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		pad_active = true
	elif (event is InputEventKey and (event as InputEventKey).pressed) or event is InputEventMouseButton:
		pad_active = false
	return was != pad_active
