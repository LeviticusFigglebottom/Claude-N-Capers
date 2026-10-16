## Scoped-ADS sight picture (LEAD 2026-10-16, PD2): at full ADS a high-power scope shows a reticle through a round
## ocular (black vignette ring with a soft edge) over the magnified world, and the gun / ocular lens is hidden (the
## lens never renders as an opaque disc). Drawn procedurally (no texture assets). CrewView owns one on its
## viewmodel CanvasLayer above the gun image, sets `amount` (0 = off .. 1 = full sight picture) from ads_blend and
## `style` / `tint` from the weapon's scope data, and hides the gun image past FpViewmodelTweak.scope_hide_gun_at.
## Low-power optics (reflex / holo / prism below FpViewmodelTweak.scope_overlay_min_mag) stay 3D. Owner: ENV P.
class_name FpScopeOverlay
extends Control

## Reticle styles; unknown styles draw DUPLEX.
const DUPLEX: StringName = &"duplex"
const MILDOT: StringName = &"mildot"
const CHEVRON: StringName = &"chevron"
const DOT: StringName = &"dot"

## 0 = hidden .. 1 = full sight picture.
var amount: float = 0.0:
	set(v):
		v = clampf(v, 0.0, 1.0)
		if not is_equal_approx(v, amount):
			amount = v
			visible = amount > 0.001
			modulate.a = amount
			queue_redraw()
var style: StringName = DUPLEX:
	set(v):
		if v != style:
			style = v
			queue_redraw()
## Sight-picture offset (px): the scope's sway / breathing moves the whole ocular (ring + reticle) on screen.
var offset: Vector2 = Vector2.ZERO:
	set(v):
		if not v.is_equal_approx(offset):
			offset = v
			queue_redraw()
## Reticle colour (an illuminated reticle sets a bright one).
var tint: Color = Color(0.02, 0.02, 0.02):
	set(v):
		if v != tint:
			tint = v
			queue_redraw()


func _init() -> void:
	name = "ScopeOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## Ocular radius (px) for a viewport of `size`.
static func ocular_radius(size: Vector2) -> float:
	return minf(size.x, size.y) * FpViewmodelTweak.data().scope_radius_frac


func _draw() -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var c: Vector2 = size * 0.5 + offset
	var r: float = ocular_radius(size)
	var far: float = (size * 0.5).length() + offset.length() + 4.0
	var black: Color = Color(0.0, 0.0, 0.0, 1.0)
	# Vignette: opaque outside the ocular, a soft dark edge just inside it.
	draw_arc(c, (r + far) * 0.5, 0.0, TAU, 160, black, far - r + 2.0, true)
	var edge: float = maxf(tw.scope_edge_px, 1.0)
	var steps: int = 8
	for i: int in steps:
		var t: float = float(i) / float(steps)
		var w: float = edge / float(steps)
		draw_arc(c, r - (t + 0.5) * w, 0.0, TAU, 160, Color(0, 0, 0, (1.0 - t) * 0.85), w + 0.5, true)
	_draw_reticle(c, r, tw)


func _draw_reticle(c: Vector2, r: float, tw: FpViewmodelTweak) -> void:
	var thin: float = maxf(tw.scope_line_px, 1.0)
	var thick: float = maxf(thin * tw.scope_post_width_mult, r * 0.03)
	match style:
		DOT:
			draw_circle(c, thin * 1.6, tint)
		CHEVRON:
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), tint, thin, true)
			draw_line(c + Vector2(0, r * 0.12), c + Vector2(0, r), tint, thin, true)
			var h: float = r * 0.06
			draw_polyline(PackedVector2Array([c + Vector2(-h, h * 1.2), c, c + Vector2(h, h * 1.2)]), tint, thin * 1.5,
				true)
		MILDOT:
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), tint, thin, true)
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), tint, thin, true)
			var step: float = r * 0.12
			for k: int in range(1, 6):
				for s: float in [-1.0, 1.0]:
					draw_circle(c + Vector2(s * step * k, 0), thin * 1.4, tint)
					draw_circle(c + Vector2(0, s * step * k), thin * 1.4, tint)
		_:  # DUPLEX: thick posts from the edge to scope_post_inner_frac of the radius, a thin cross in the middle
			var inner: float = r * tw.scope_post_inner_frac
			draw_line(c + Vector2(-r, 0), c + Vector2(-inner, 0), tint, thick, true)
			draw_line(c + Vector2(inner, 0), c + Vector2(r, 0), tint, thick, true)
			draw_line(c + Vector2(0, inner), c + Vector2(0, r), tint, thick, true)
			draw_line(c + Vector2(0, -r), c + Vector2(0, -inner), tint, thick, true)
			draw_line(c + Vector2(-inner, 0), c + Vector2(inner, 0), tint, thin, true)
			draw_line(c + Vector2(0, -inner), c + Vector2(0, inner), tint, thin, true)
