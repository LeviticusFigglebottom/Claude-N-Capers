## Current objective (PO-4, docs/design/ui/style.md §8): a caption "OBJECTIVE" over ONE line, the
## first ACTIVE objective (PD2 shows the current step, not the whole plan; the full list is on the
## scoreboard). Hidden when nothing is active. B4-07: the heist's accent (UiAccent; set_accent) edges
## the panel and tints the caption.
class_name ObjectivesPanel
extends HudWidget

## Seconds the "complete" caption stays before the next step shows.
const FLASH_S: float = 2.4
## Seconds the finished step stays struck through before the next one slides in.
const STRIKE_S: float = 1.0

## objective_text()'s cleanup patterns for unfilled "{arg}" placeholders (compiled on first use).
static var _unfilled_group: RegEx = null
static var _unfilled: RegEx = null

var list_box: VBoxContainer
var header_label: Label
var panel: PanelContainer
## Heist accent (alpha 0 = none).
var accent: Color = Color(0, 0, 0, 0)
## Bags secured this run (EventBus.loot_secured), the {count} of "Secure the bags ({count}/{total})".
var secured_count: int = 0
## Id of the objective on the line (&"" = none) and whether the "complete" flash is showing (tests).
var shown_id: StringName = &""
var flashing: bool = false
## The finished step, struck through, shown during the flash (lead h02 note).
var done_label: RichTextLabel
## PO6-03: the current objective's device timer ("DRILL 02:31" / "DRILL JAMMED" in red) under the active line.
var device_label: Label = null
var _flash_tween: Tween = null
var _shown_text: String = ""
var _done_text: String = ""
## The one active-objective line (reused across refreshes).
var _active: Label = null


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	panel = UiBuild.panel(v, UiBuild.HUD_PANEL)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(panel)
	header_label = UiBuild.float_text(UiBuild.caption(&"ui.hud.objectives"))
	header_label.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	v.add_child(header_label)
	done_label = RichTextLabel.new()
	done_label.bbcode_enabled = true
	done_label.fit_content = true
	done_label.scroll_active = false
	done_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	done_label.custom_minimum_size = Vector2(380, 0)
	done_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	done_label.add_theme_font_size_override(&"normal_font_size", UiTokens.FONT_LEAD)
	done_label.add_theme_color_override(&"default_color", UiTokens.OK)
	done_label.add_theme_constant_override(&"outline_size", UiBuild.FLOAT_OUTLINE_SIZE)
	done_label.add_theme_color_override(&"font_outline_color", UiBuild.FLOAT_OUTLINE_COLOR)
	done_label.visible = false
	v.add_child(done_label)
	list_box = UiBuild.vbox(UiTokens.S1)
	v.add_child(list_box)
	_apply_accent()


## Accent the panel edge and header with `color` (readable against the HUD panel).
func set_accent(color: Color) -> void:
	accent = color
	_apply_accent()


## Display text of objective `o` with its placeholders filled (lead bug: the HUD showed a raw
## "Secure the bags ({count}/{total})"). Missions pass {"bags": N} (no count / total), so total falls back
## to bags / required and count to secured / `secured`. A placeholder still unfilled is dropped together
## with its "( ... )" group, so raw braces never reach the screen.
## PO6-03 (DeviceTimers.objective_suffix_changed): show `text` under the active objective ("" hides it), red while jammed.
func set_device_suffix(text: String, jammed: bool) -> void:
	if device_label == null or not is_instance_valid(device_label):
		device_label = UiBuild.label(&"", UiBuild.HUD)
		device_label.name = "DeviceLine"
	device_label.text = text
	device_label.add_theme_color_override(&"font_color", tweak.device_jam_color if jammed else UiTokens.PAPER)
	if text != "" and device_label.get_parent() == null and list_box != null:
		list_box.add_child(device_label)
	elif text == "" and device_label.get_parent() != null:
		device_label.get_parent().remove_child(device_label)
	_device_last()
	visible = (list_box != null and list_box.get_child_count() > 0) or flashing


## The device line always sits under the active step.
func _device_last() -> void:
	if device_label != null and list_box != null and device_label.get_parent() == list_box:
		list_box.move_child(device_label, -1)


static func objective_text(o: Dictionary, secured: int = 0) -> String:
	var args: Dictionary = (o.get("args", {}) as Dictionary).duplicate()
	if not args.has("total"):
		for k: String in ["bags", "required", "min_bags"]:
			if args.has(k):
				args["total"] = args[k]
				break
	if not args.has("count"):
		args["count"] = args.get("secured", args.get("bags_secured", secured))
	var text: String = UiText.t(StringName(o.get("text_key", &"")), args)
	if text.contains("{"):
		if _unfilled_group == null:  # compiled once (objective_text runs for markers too)
			_unfilled_group = RegEx.create_from_string("\\s*\\([^()]*\\{[A-Za-z_]+\\}[^()]*\\)")
			_unfilled = RegEx.create_from_string("\\{[A-Za-z_]+\\}")
		text = _unfilled_group.sub(text, "", true)
		text = _unfilled.sub(text, "", true).strip_edges()
	return text


func _on_loot_secured(_bag_net_id: int, _loot_id: StringName, _value: int) -> void:
	secured_count += 1
	if is_inside_tree():
		refresh()


func _enter_tree() -> void:
	if not EventBus.loot_secured.is_connected(_on_loot_secured):
		EventBus.loot_secured.connect(_on_loot_secured)


func _exit_tree() -> void:
	if EventBus.loot_secured.is_connected(_on_loot_secured):
		EventBus.loot_secured.disconnect(_on_loot_secured)


func _apply_accent() -> void:
	if panel == null:
		return
	# PO-4: a hairline accent on the left edge only (frameless HUD); house brass without a heist accent.
	var edge: StyleBoxFlat = (UiBuild.theme().get_stylebox(&"panel", UiBuild.HUD_PANEL) as StyleBoxFlat).duplicate() as StyleBoxFlat
	edge.border_color = accent if accent.a > 0.0 else UiTokens.BRASS
	edge.border_width_left = 3
	edge.content_margin_left = UiTokens.S3
	panel.add_theme_stylebox_override(&"panel", edge)
	if accent.a <= 0.0:
		return
	var sb: StyleBoxFlat = panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	var back: Color = UiAccent.over(sb.bg_color, UiAccent.app_bg()) if sb != null else UiAccent.app_bg()
	header_label.add_theme_color_override(&"font_color", UiAccent.readable(accent, back, UiAccent.table().min_text_contrast))


## PO-4 motion (style.md §8): "OBJECTIVE COMPLETE" in OK green over the finished step, struck through,
## for FLASH_S; then the caption returns to OBJECTIVE and only then the next step fades in (T_SLOW).
func _flash_complete() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	flashing = true
	UiSfx.play(UiSfx.OBJECTIVE_DONE)  # D-090
	header_label.text = UiText.t(&"ui.hud.objective_complete")
	header_label.add_theme_color_override(&"font_color", UiTokens.OK)
	# The finished step, struck through, under the caption (the next step waits for the flash to end).
	done_label.text = "[s]%s[/s]" % _done_text
	done_label.visible = _done_text != ""
	done_label.modulate.a = 1.0
	list_box.visible = false
	_flash_tween = create_tween()
	# Lead (A's ND analysis): "OBJECTIVE COMPLETE" must only ever sit over the FINISHED step. The struck
	# line stays for the whole flash; the caption returns to OBJECTIVE first, then the next step fades in.
	_flash_tween.tween_interval(FLASH_S)
	if UiTokens.motion_ok():
		_flash_tween.tween_property(done_label, ^"modulate:a", 0.0, UiTokens.T_BASE)
	_flash_tween.tween_callback(_end_flash)
	_flash_tween.tween_callback(_show_next)
	if UiTokens.motion_ok():
		_flash_tween.tween_property(list_box, ^"modulate:a", 1.0, UiTokens.T_SLOW).set_ease(Tween.EASE_OUT)
	else:
		_flash_tween.tween_callback(func() -> void: list_box.modulate.a = 1.0)


func _show_next() -> void:
	done_label.visible = false
	list_box.visible = true
	list_box.modulate.a = 0.0 if UiTokens.motion_ok() else 1.0


func _end_flash() -> void:
	flashing = false
	done_label.visible = false
	header_label.text = UiText.t(&"ui.hud.objectives")
	header_label.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	_apply_accent()
	visible = list_box.get_child_count() > 0


func watched_signals() -> Array[StringName]:
	return [&"objectives_changed"]


func refresh() -> void:
	var new_id: StringName = &""
	var still_active: bool = false  # the shown step is still ACTIVE (another step went ahead of it)
	if _active == null:  # one line, reused (perf: no node churn per objectives_changed)
		_active = UiBuild.label(&"", UiBuild.HUD)
		_active.add_theme_font_size_override(&"font_size", UiTokens.FONT_LEAD)
		_active.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_active.custom_minimum_size = Vector2(380, 0)
	for o: Dictionary in prop(&"objectives", []) as Array:
		if int(o.get("state", Enums.ObjectiveState.ACTIVE)) != Enums.ObjectiveState.ACTIVE:
			continue
		if StringName(o.get("id", &"")) == shown_id:
			still_active = true
		if new_id != &"":
			continue
		if bool((o.get("args", {}) as Dictionary).get("disabled", false)):
			continue  # PO-5.6: e.g. the keycard step in a lockdown; the next live step shows instead
		var t: String = UiText.t(&"ui.hud.objective_active", {"text": objective_text(o, secured_count)})
		if _active.text != t:
			_active.text = t
		new_id = StringName(o.get("id", &""))
	if new_id != &"" and _active.get_parent() == null:
		list_box.add_child(_active)
	elif new_id == &"" and _active.get_parent() == list_box:
		list_box.remove_child(_active)
	# GN-B1 capture: a step that jumps ahead (Gallery Night's Argus lockdown) used to flash the step it
	# displaced as "OBJECTIVE COMPLETE" while that step was still to do. Only a finished step flashes.
	if new_id != shown_id and shown_id != &"" and not still_active and is_inside_tree():
		_done_text = _shown_text
		_flash_complete()
	shown_id = new_id
	_device_last()
	_shown_text = (list_box.get_child(0) as Label).text if list_box.get_child_count() > 0 else ""
	visible = list_box.get_child_count() > 0 or flashing


static func _state_key(st: int) -> StringName:
	match st:
		Enums.ObjectiveState.COMPLETED:
			return &"ui.hud.objective_done"
		Enums.ObjectiveState.FAILED:
			return &"ui.hud.objective_failed"
	return &"ui.hud.objective_active"
