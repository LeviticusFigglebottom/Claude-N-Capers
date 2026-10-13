## Row factories for the options screen (B5-01). Owner: ENV B. Each row edits one GameSettings key
## of the screen's draft: label (strings key `ui.options.<section>.<key>`) + control. Returns the
## focusable control; the row is added to `parent`. Specs come from SettingsDefaults.
class_name OptionsRows
extends RefCounted

const LABEL_WIDTH: float = 480.0
const CONTROL_WIDTH: float = 420.0


## strings.csv key of a setting's label.
static func label_key(section: StringName, key: StringName) -> StringName:
	return StringName("ui.options.%s.%s" % [section, String(key).to_lower()])


## strings.csv key of a choice option (palette ids use ui.options.palette.<id>, hold/toggle ui.options.mode.<id>).
static func option_key(section: StringName, key: StringName, option: String) -> StringName:
	if key == &"palette":
		return StringName("ui.options.palette.%s" % option)
	if String(key).ends_with("_mode") and section == GameSettings.CONTROLS:
		return StringName("ui.options.mode.%s" % option)
	return StringName("ui.options.%s.%s.%s" % [section, key, option])


## Value text for slider rows: percent for 0..1-ish ranges, degrees for fov, multiplier for sensitivity.
static func value_text(_section: StringName, key: StringName, v: float) -> String:
	if key == &"fov":
		return UiText.t(&"ui.options.value.degrees", {"value": roundi(v)})
	if String(key).contains("sensitivity"):
		return UiText.t(&"ui.options.value.multiplier", {"value": "%.2f" % v})
	return UiText.t(&"ui.options.value.percent", {"value": roundi(v * 100.0)})


static func slider(parent: Container, s: GameSettings, section: StringName, key: StringName) -> HSlider:
	var sp: Dictionary = s.defaults.spec(section, key)
	var row: HBoxContainer = _row(parent, section, key)
	var sl: HSlider = HSlider.new()
	sl.name = "Slider"
	sl.min_value = float(sp.get("min", 0.0))
	sl.max_value = float(sp.get("max", 1.0))
	sl.step = float(sp.get("step", 0.01))
	sl.value = float(s.get_value(section, key))
	sl.focus_mode = Control.FOCUS_ALL
	sl.custom_minimum_size = Vector2(CONTROL_WIDTH, UiTokens.S5)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sl)
	var val: Label = UiBuild.label(&"", UiBuild.DIM)
	val.name = "Value"
	val.custom_minimum_size = Vector2(120, 0)
	val.text = value_text(section, key, sl.value)
	row.add_child(val)
	sl.value_changed.connect(func(v: float) -> void:
		s.set_value(section, key, v)
		val.text = value_text(section, key, v))
	return sl


static func toggle(parent: Container, s: GameSettings, section: StringName, key: StringName) -> CheckButton:
	var row: HBoxContainer = _row(parent, section, key)
	var cb: CheckButton = CheckButton.new()
	cb.name = "Toggle"
	cb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	cb.focus_mode = Control.FOCUS_ALL
	cb.button_pressed = bool(s.get_value(section, key))
	cb.text = UiText.t(&"ui.options.on") if cb.button_pressed else UiText.t(&"ui.options.off")
	cb.toggled.connect(func(on: bool) -> void:
		s.set_value(section, key, on)
		cb.text = UiText.t(&"ui.options.on") if on else UiText.t(&"ui.options.off"))
	row.add_child(cb)
	return cb


## Dropdown of the spec's options (choice: strings; int: numbers, e.g. max_fps).
static func choice(parent: Container, s: GameSettings, section: StringName, key: StringName) -> OptionButton:
	var sp: Dictionary = s.defaults.spec(section, key)
	var row: HBoxContainer = _row(parent, section, key)
	var ob: OptionButton = UiBuild.option_button()
	ob.name = "Choice"
	ob.custom_minimum_size = Vector2(CONTROL_WIDTH, 0)
	var opts: Array = (sp.get("options", []) as Array).duplicate()
	var cur: Variant = s.get_value(section, key)
	if not opts.has(cur):
		opts.append(cur)  # an int value set in the file but not offered (max_fps 75)
	for o: Variant in opts:
		ob.add_item(_option_text(section, key, o))
		ob.set_item_metadata(ob.item_count - 1, o)
		if o == cur:
			ob.select(ob.item_count - 1)
	ob.item_selected.connect(func(i: int) -> void: s.set_value(section, key, ob.get_item_metadata(i)))
	row.add_child(ob)
	return ob


## Deferred grab_focus that skips controls freed or removed in the meantime (pages are rebuilt).
static func focus_later(c: Control) -> void:
	var grab: Callable = func() -> void:
		if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree():
			c.grab_focus()
	grab.call_deferred()


static func _option_text(section: StringName, key: StringName, o: Variant) -> String:
	if o is int:
		return UiText.t(&"ui.options.video.max_fps.unlimited") if int(o) == 0 else UiText.t(&"ui.options.video.max_fps.value", {"value": o})
	return UiText.t(option_key(section, key, String(o)))


static func _row(parent: Container, section: StringName, key: StringName) -> HBoxContainer:
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	row.name = "Row_%s" % key
	var l: Label = UiBuild.caption(label_key(section, key))  # PO-4: field names are captions
	l.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	parent.add_child(row)
	return row
