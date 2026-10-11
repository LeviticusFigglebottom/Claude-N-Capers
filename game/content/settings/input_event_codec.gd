## InputEvent <-> plain Dictionary (settings file, never objects) and display text. Owner: ENV B.
## Shapes (content/docs/options.md):
##   {"type": "key", "keycode": int, "physical": bool}      physical = physical_keycode (layout independent)
##   {"type": "mouse_button", "button": int}                 MouseButton (1 left .. 9 xbutton2)
##   {"type": "joy_button", "button": int}                   JoyButton
##   {"type": "joy_motion", "axis": int, "dir": 1 | -1}      JoyAxis + direction (axis_value +-1.0)
## Columns: KBM (key, mouse_button) and PAD (joy_button, joy_motion). Modifiers are not part of a
## binding (no chords); device is always "all devices" (-1).
class_name InputEventCodec
extends RefCounted

const KBM: StringName = &"kbm"
const PAD: StringName = &"pad"
const COLUMNS: Array[StringName] = [KBM, PAD]
const T_KEY: String = "key"
const T_MOUSE: String = "mouse_button"
const T_JOY_BUTTON: String = "joy_button"
const T_JOY_MOTION: String = "joy_motion"
## A stick / trigger counts as "pressed" for capture past this deflection.
const CAPTURE_AXIS_MIN: float = 0.6
const MAX_JOY_BUTTON: int = 127
const MAX_MOUSE_BUTTON: int = 9


## Plain dict for `e` ({} for events that cannot be a binding, e.g. mouse motion).
static func to_dict(e: InputEvent) -> Dictionary:
	var d: Dictionary = {}
	if e is InputEventKey:
		var k: InputEventKey = e as InputEventKey
		var physical: bool = k.physical_keycode != KEY_NONE
		var code: int = int(k.physical_keycode) if physical else int(k.keycode)
		if code != KEY_NONE:
			d = {"type": T_KEY, "keycode": code, "physical": physical}
	elif e is InputEventMouseButton:
		d = {"type": T_MOUSE, "button": int((e as InputEventMouseButton).button_index)}
	elif e is InputEventJoypadButton:
		d = {"type": T_JOY_BUTTON, "button": int((e as InputEventJoypadButton).button_index)}
	elif e is InputEventJoypadMotion:
		var m: InputEventJoypadMotion = e as InputEventJoypadMotion
		d = {"type": T_JOY_MOTION, "axis": int(m.axis), "dir": 1 if m.axis_value >= 0.0 else -1}
	return sanitize(d)


## A fresh InputEvent (device -1) for a dict; null when the dict is invalid.
static func from_dict(raw: Variant) -> InputEvent:
	var d: Dictionary = sanitize(raw)
	var out: InputEvent = null
	match String(d.get("type", "")):
		T_KEY:
			var k: InputEventKey = InputEventKey.new()
			if bool(d["physical"]):
				k.physical_keycode = int(d["keycode"]) as Key
			else:
				k.keycode = int(d["keycode"]) as Key
			out = k
		T_MOUSE:
			var mb: InputEventMouseButton = InputEventMouseButton.new()
			mb.button_index = int(d["button"]) as MouseButton
			out = mb
		T_JOY_BUTTON:
			var jb: InputEventJoypadButton = InputEventJoypadButton.new()
			jb.button_index = int(d["button"]) as JoyButton
			out = jb
		T_JOY_MOTION:
			var jm: InputEventJoypadMotion = InputEventJoypadMotion.new()
			jm.axis = int(d["axis"]) as JoyAxis
			jm.axis_value = float(d["dir"])
			out = jm
	if out != null:
		out.device = -1
	return out


## Canonical copy of a binding dict, or {} when it is not a valid binding.
static func sanitize(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var d: Dictionary = raw as Dictionary
	var out: Dictionary = {}
	match String(d.get("type", "")):
		T_KEY:
			if _int_in(d.get("keycode"), 1, 0x7FFFFFFF):
				out = {"type": T_KEY, "keycode": int(d["keycode"]), "physical": d.get("physical", true) is bool and bool(d.get("physical", true))}
		T_MOUSE:
			if _int_in(d.get("button"), 1, MAX_MOUSE_BUTTON):
				out = {"type": T_MOUSE, "button": int(d["button"])}
		T_JOY_BUTTON:
			if _int_in(d.get("button"), 0, MAX_JOY_BUTTON):
				out = {"type": T_JOY_BUTTON, "button": int(d["button"])}
		T_JOY_MOTION:
			if _int_in(d.get("axis"), 0, int(JOY_AXIS_MAX) - 1) and _int_in(d.get("dir"), -1, 1) and int(d["dir"]) != 0:
				out = {"type": T_JOY_MOTION, "axis": int(d["axis"]), "dir": int(d["dir"])}
	return out


## KBM or PAD for a binding dict (&"" when invalid).
static func column_of(d: Dictionary) -> StringName:
	var t: String = String(d.get("type", ""))
	if t == T_KEY or t == T_MOUSE:
		return KBM
	if t == T_JOY_BUTTON or t == T_JOY_MOTION:
		return PAD
	return &""


## Same physical input (a key matches whether it was stored as physical or as keycode).
static func same(a: Dictionary, b: Dictionary) -> bool:
	var sa: Dictionary = sanitize(a)
	var sb: Dictionary = sanitize(b)
	if sa.is_empty() or sb.is_empty() or sa["type"] != sb["type"]:
		return false
	match String(sa["type"]):
		T_KEY:
			return int(sa["keycode"]) == int(sb["keycode"])
		T_JOY_MOTION:
			return int(sa["axis"]) == int(sb["axis"]) and int(sa["dir"]) == int(sb["dir"])
	return int(sa["button"]) == int(sb["button"])


## The binding a "press a key" capture reads from a raw event in `column` ({} = keep waiting):
## a key / mouse button press for KBM; a pad button press or a stick / trigger pushed past
## CAPTURE_AXIS_MIN for PAD. Captured keys are stored as physical keys.
static func capture(e: InputEvent, column: StringName) -> Dictionary:
	var d: Dictionary = {}
	if column == KBM:
		var k: InputEventKey = e as InputEventKey
		if k != null and k.pressed and not k.echo:
			var code: int = int(k.physical_keycode) if k.physical_keycode != KEY_NONE else int(k.keycode)
			d = sanitize({"type": T_KEY, "keycode": code, "physical": k.physical_keycode != KEY_NONE})
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if mb != null and mb.pressed:
			d = to_dict(mb)
	elif column == PAD:
		var jb: InputEventJoypadButton = e as InputEventJoypadButton
		if jb != null and jb.pressed:
			d = to_dict(jb)
		var jm: InputEventJoypadMotion = e as InputEventJoypadMotion
		if jm != null and absf(jm.axis_value) >= CAPTURE_AXIS_MIN:
			d = to_dict(jm)
	return d


## Display text: "F", "Mouse Left", "Pad A / Cross", "Left Stick Up" ... (strings.csv).
static func text(d: Dictionary) -> String:
	var s: Dictionary = sanitize(d)
	var out: String = ""
	match String(s.get("type", "")):
		T_KEY:
			out = OS.get_keycode_string(int(s["keycode"]) as Key)
		T_MOUSE:
			out = UiText.t(StringName("ui.options.input.mouse_%d" % int(s["button"])))
		T_JOY_BUTTON:
			var key: StringName = StringName("ui.options.pad.button_%d" % int(s["button"]))
			out = UiText.t(key) if int(s["button"]) <= 15 else UiText.t(&"ui.options.pad.button", {"n": int(s["button"])})
		T_JOY_MOTION:
			var axis: int = int(s["axis"])
			var sign_name: String = "pos" if int(s["dir"]) > 0 else "neg"
			out = UiText.t(StringName("ui.options.pad.axis_%d_%s" % [axis, sign_name])) if axis <= 5 \
					else UiText.t(&"ui.options.pad.axis", {"n": axis, "dir": "+" if int(s["dir"]) > 0 else "-"})
	return out


static func _int_in(v: Variant, lo: int, hi: int) -> bool:
	if not (v is int or v is float):
		return false
	var f: float = float(v)
	return is_finite(f) and f == roundf(f) and int(f) >= lo and int(f) <= hi
