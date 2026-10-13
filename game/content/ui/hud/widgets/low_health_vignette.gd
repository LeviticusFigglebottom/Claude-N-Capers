## Low-health warning (lead round 62, PD2): below THRESHOLD of max health while standing (crew_state
## NORMAL), a red vignette darkens the screen edges and pulses with a heartbeat (cue.hud_heartbeat
## once per beat). The lower the health, the faster the beat (BEAT_SLOW_S at the threshold ->
## BEAT_FAST_S near 0) and the stronger the edge. Reduce Motion keeps the vignette steady (the
## heartbeat still plays). Owner: ENV B.
class_name LowHealthVignette
extends HudWidget

const THRESHOLD: float = 0.25
const BEAT_SLOW_S: float = 1.1
const BEAT_FAST_S: float = 0.6
const EDGE_ALPHA_MIN: float = 0.35
const EDGE_ALPHA_MAX: float = 0.7

## 0 = off, else 1 - health fraction / THRESHOLD (0..1, tests).
var severity: float = 0.0
## Beats played since the warning started (tests).
var beats: int = 0
var rect: TextureRect
var _beat_t: float = 0.0
var _phase: float = 0.0


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect = TextureRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(UiTokens.ALERT_INK, 0.0))
	g.set_color(1, Color(UiTokens.ALERT, 1.0))
	g.add_point(0.55, Color(UiTokens.ALERT_INK, 0.0))
	g.add_point(0.85, Color(UiTokens.ALERT_INK, 0.75))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	rect.texture = tex
	add_child(rect)
	visible = false


func watched_signals() -> Array[StringName]:
	return [&"vitals_changed"]


func refresh() -> void:
	var mx: float = float(prop(&"max_health", 0.0))
	var hp: float = float(prop(&"health", 0.0))
	var standing: bool = int(prop(&"crew_state", Enums.CrewState.NORMAL)) == Enums.CrewState.NORMAL
	var frac: float = hp / mx if mx > 0.0 else 1.0
	var was: bool = severity > 0.0
	severity = clampf(1.0 - frac / THRESHOLD, 0.0, 1.0) if standing and hp > 0.0 and frac < THRESHOLD else 0.0
	visible = severity > 0.0
	set_process(visible)
	if visible and not was:
		beats = 0
		_beat_t = 0.0  # first beat right away
	_apply(0.0)


func beat_period() -> float:
	return lerpf(BEAT_SLOW_S, BEAT_FAST_S, severity)


func _process(delta: float) -> void:
	_beat_t -= delta
	if _beat_t <= 0.0:
		_beat_t += beat_period()
		_phase = 0.0
		beats += 1
		UiSfx.play(UiSfx.HEARTBEAT)
	_phase += delta
	_apply(_phase)


## Vignette strength: the base for this severity plus a short swell after each beat.
func _apply(since_beat: float) -> void:
	if rect == null:
		return
	var base: float = lerpf(EDGE_ALPHA_MIN, EDGE_ALPHA_MAX, severity)
	var swell: float = 0.0
	if UiTokens.motion_ok():
		swell = 0.25 * exp(-since_beat * 6.0)
	rect.modulate.a = clampf(base + swell, 0.0, 1.0)
