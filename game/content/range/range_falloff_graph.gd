## Falloff graph (B4-13, pd2_fidelity P7): damage of one shot (all pellets, body) against distance
## for the current resolved weapon, drawn in code, with a marker at the readout distance.
## Owner: ENV B. The curve is sampled from RangeMath.shot_damage (the same falloff the readout and
## the weapon runtime use), so `samples()` equals RangeMath at every sample distance.
class_name RangeFalloffGraph
extends Control

const PAD_LEFT: float = 56.0
const PAD_RIGHT: float = 10.0
const PAD_TOP: float = 10.0
const PAD_BOTTOM: float = 28.0

var stats: WeaponStats = null
var marker_distance_m: float = -1.0
var tweak: RangeTweak = null

var _samples: PackedVector2Array = PackedVector2Array()


func setup(range_tweak: RangeTweak) -> void:
	tweak = range_tweak
	custom_minimum_size = Vector2(0.0, float(tweak.graph_height_px))
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## New weapon stats and/or readout distance (m, < 0 = no marker).
func show_falloff(s: WeaponStats, distance_m: float) -> void:
	var changed: bool = s != stats
	stats = s
	marker_distance_m = distance_m
	if changed or _samples.is_empty():
		_samples = sample(s, tweak.graph_samples, tweak.graph_max_distance_m)
	queue_redraw()


## (distance m, shot damage) at `n` evenly spaced distances from 0 to `max_m` inclusive, plus the
## falloff start/end breakpoints so the polyline is exact.
static func sample(s: WeaponStats, n: int, max_m: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if s == null:
		return out
	var ds: Array[float] = []
	for i: int in range(maxi(n, 2)):
		ds.append(max_m * float(i) / float(maxi(n, 2) - 1))
	for d: float in [s.falloff_start_m, s.falloff_end_m]:
		if d > 0.0 and d < max_m and not ds.has(d):
			ds.append(d)
	ds.sort()
	for d: float in ds:
		out.append(Vector2(d, RangeMath.shot_damage(s, d)))
	return out


func samples() -> PackedVector2Array:
	return _samples


## Graph-space point for (distance, damage) inside the plot rect.
func to_canvas(p: Vector2) -> Vector2:
	var r: Rect2 = _plot_rect()
	var top: float = _max_damage()
	var x: float = r.position.x + r.size.x * clampf(p.x / tweak.graph_max_distance_m, 0.0, 1.0)
	var y: float = r.end.y - r.size.y * clampf(p.y / top, 0.0, 1.0) if top > 0.0 else r.end.y
	return Vector2(x, y)


func _plot_rect() -> Rect2:
	return Rect2(Vector2(PAD_LEFT, PAD_TOP), Vector2(maxf(size.x - PAD_LEFT - PAD_RIGHT, 1.0), maxf(size.y - PAD_TOP - PAD_BOTTOM, 1.0)))


func _max_damage() -> float:
	var m: float = 0.0
	for p: Vector2 in _samples:
		m = maxf(m, p.y)
	return m * 1.1


func _draw() -> void:
	if tweak == null:
		return
	var r: Rect2 = _plot_rect()
	var font: Font = get_theme_default_font()
	var fs: int = tweak.graph_font_size
	draw_line(Vector2(r.position.x, r.end.y), r.end, tweak.graph_axis_color, 1.0)
	draw_line(r.position, Vector2(r.position.x, r.end.y), tweak.graph_axis_color, 1.0)
	var steps: int = 4
	for i: int in range(steps + 1):
		var d: float = tweak.graph_max_distance_m * float(i) / float(steps)
		var x: float = r.position.x + r.size.x * float(i) / float(steps)
		draw_line(Vector2(x, r.end.y), Vector2(x, r.end.y + 4.0), tweak.graph_axis_color, 1.0)
		var txt: String = UiText.t(&"ui.range.fmt.m", {"value": roundi(d)})
		# The first label starts at its tick, the last ends at it (it was clipped at the panel edge), others centre.
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tx: float = x if i == 0 else (x - tw if i == steps else x - tw * 0.5)
		draw_string(font, Vector2(tx, r.end.y + 4.0 + float(fs)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tweak.graph_axis_color)
	if _samples.size() < 2:
		return
	var top: float = _max_damage() / 1.1
	draw_string(font, Vector2(2.0, r.position.y + float(fs)), String.num(top, 0), HORIZONTAL_ALIGNMENT_LEFT,
			PAD_LEFT - 4.0, fs, tweak.graph_axis_color)
	draw_string(font, Vector2(2.0, r.end.y), "0", HORIZONTAL_ALIGNMENT_LEFT, PAD_LEFT - 4.0, fs, tweak.graph_axis_color)
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in _samples:
		pts.append(to_canvas(p))
	# D-111: where falloff starts and ends (dashed guides), and a mid-damage tick, so the curve reads at a glance.
	for d: float in [stats.falloff_start_m, stats.falloff_end_m] if stats != null else []:
		if d > 0.0 and d < tweak.graph_max_distance_m:
			var gx: float = to_canvas(Vector2(d, 0.0)).x
			draw_dashed_line(Vector2(gx, r.position.y), Vector2(gx, r.end.y), tweak.graph_axis_color, 1.0, 4.0)
	var mid_y: float = to_canvas(Vector2(0.0, top * 0.5)).y
	draw_line(Vector2(r.position.x - 4.0, mid_y), Vector2(r.position.x, mid_y), tweak.graph_axis_color, 1.0)
	draw_string(font, Vector2(2.0, mid_y + float(fs) * 0.4), String.num(top * 0.5, 0), HORIZONTAL_ALIGNMENT_LEFT,
			PAD_LEFT - 4.0, fs, tweak.graph_axis_color)
	draw_polyline(pts, tweak.graph_line_color, 3.0, true)
	if marker_distance_m >= 0.0 and stats != null:
		var dmg: float = RangeMath.shot_damage(stats, minf(marker_distance_m, tweak.graph_max_distance_m))
		var c: Vector2 = to_canvas(Vector2(marker_distance_m, dmg))
		draw_line(Vector2(c.x, r.position.y), Vector2(c.x, r.end.y), tweak.graph_marker_color, 1.0)
		draw_circle(c, 4.0, tweak.graph_marker_color)
		var label: String = UiText.t(&"ui.range.graph_marker", {"m": String.num(marker_distance_m, 1), "dmg": String.num(dmg, 1)})
		var label_w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lx: float = c.x + 6.0 if c.x < r.position.x + r.size.x * 0.6 else c.x - 6.0 - label_w
		draw_string(font, Vector2(lx, r.position.y + float(fs)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tweak.graph_marker_color)
