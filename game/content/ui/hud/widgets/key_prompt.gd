## PO-4: one line of HUD prompt text with the input drawn as a key cap: "Hold [F] to pick the lock".
## The strings-table text keeps its `{key}` placeholder; set_prompt() splits the translated line around
## it, so word order follows the language. A line without `{key}` is plain text. Floating text style
## (PQ-B-23 outline + shadow) on both text parts. Owner: ENV B.
class_name KeyPrompt
extends HBoxContainer

const _MARK: String = "\u0001"

## Full display text, the key name included ("Hold F to pick the lock").
var text: String = ""
var left: Label
var right: Label
var cap: PanelContainer
var cap_label: Label


func _init(font_size: int = UiTokens.FONT_HUD) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", UiTokens.S2)
	left = _part(font_size)
	cap = UiBuild.keycap("", font_size)
	cap_label = cap.get_child(0) as Label
	add_child(cap)
	right = _part(font_size)


func _part(font_size: int) -> Label:
	var l: Label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD))
	l.add_theme_font_size_override(&"font_size", font_size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	return l


## Shows `text_key` translated with `args`; `{key}` becomes a key cap reading `key_text`.
func set_prompt(text_key: StringName, args: Dictionary = {}, key_text: String = "") -> void:
	var a: Dictionary = args.duplicate()
	if not a.has("key"):
		a["key"] = key_text
	key_text = String(a["key"])
	text = UiText.t(text_key, a)
	a["key"] = _MARK
	set_line(UiText.t(text_key, a), key_text)


## Shows an already translated `line` whose key position is marked by \u0001 (or none).
func set_line(line: String, key_text: String) -> void:
	var at: int = line.find(_MARK)
	if at < 0 or key_text == "":
		left.text = line.replace(_MARK, key_text)
		text = left.text
		right.text = ""
		cap.visible = false
	else:
		left.text = line.left(at).strip_edges()
		right.text = line.substr(at + _MARK.length()).strip_edges()
		cap_label.text = key_text
		cap.theme_type_variation = UiBuild.keycap_variation(key_text)
		cap.visible = true
		text = line.replace(_MARK, key_text)
	left.visible = left.text != ""
	right.visible = right.text != ""


## Tints the text parts (the key cap keeps its paper edge).
func set_color(c: Color) -> void:
	left.add_theme_color_override(&"font_color", c)
	right.add_theme_color_override(&"font_color", c)
