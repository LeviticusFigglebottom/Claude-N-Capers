## PO6-17b (ui_hud v1.15): breach-blast white-out. LocalHudModel.flashed_s (seconds of flash left, up to 2.5 s at the
## blast) whites out the screen, fading with the value: alpha = max_alpha x (left / HudTweak.flash_full_s)^curve. The
## model polls at ~10 Hz, so between snapshots the widget counts down itself (1 s per s) and re-syncs on each change.
## Covers the HUD too (a flash blinds you, PD2). Owner: ENV B.
class_name BreachFlash
extends HudWidget

## Seconds of flash left as shown (tests).
var left_s: float = 0.0
var rect: ColorRect


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect = ColorRect.new()
	rect.name = "WhiteOut"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(tweak.flash_color, 0.0)
	add_child(rect)
	visible = false


func watched_signals() -> Array[StringName]:
	return [&"vitals_changed"]


func refresh() -> void:
	var v: float = float(prop(&"flashed_s", 0.0))
	if absf(v - left_s) > 0.15 or v <= 0.0 or v > left_s:
		left_s = maxf(v, 0.0)
	_apply()
	set_process(left_s > 0.0)


## 0..1 white-out strength for `seconds_left`.
func alpha_for(seconds_left: float) -> float:
	var t: float = clampf(seconds_left / maxf(tweak.flash_full_s, 0.01), 0.0, 1.0)
	return tweak.flash_max_alpha * pow(t, tweak.flash_curve)


func _process(delta: float) -> void:
	left_s = maxf(left_s - delta, 0.0)
	_apply()
	if left_s <= 0.0:
		set_process(false)


func _apply() -> void:
	if rect == null:
		return
	var a: float = alpha_for(left_s)
	rect.color = Color(tweak.flash_color, a)
	visible = a > 0.001
