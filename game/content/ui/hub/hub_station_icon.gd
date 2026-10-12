## Station glyph for the 2D safehouse hub (B4-07). Owner: ENV B. Drawn in code (no image assets):
## simple, confident line shapes in the house accent on a chamfered tile.
class_name HubStationIcon
extends Control

var kind: StringName = &""
var color: Color = Color(0.886, 0.737, 0.333, 1)
var tile_color: Color = Color(0.07, 0.063, 0.055, 1)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(72, 72)


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(s, s)) * 0.5
	var ch: float = s * 0.16
	var tile: PackedVector2Array = PackedVector2Array([o + Vector2(ch, 0), o + Vector2(s, 0), o + Vector2(s, s - ch),
			o + Vector2(s - ch, s), o + Vector2(0, s), o + Vector2(0, ch)])
	draw_colored_polygon(tile, tile_color)
	var c: Vector2 = o + Vector2(s, s) * 0.5
	var w: float = maxf(2.0, s * 0.045)
	var u: float = s * 0.5
	match kind:
		&"board":
			_board(c, u, w)
		&"planning":
			_planning(c, u, w)
		&"armory":
			_armory(c, u, w)
		&"masks":
			_masks(c, u, w)
		&"range":
			_range(c, u, w)
		&"crew":
			_crew(c, u, w)
		&"jukebox":
			_jukebox(c, u, w)
		&"notoriety":
			_notoriety(c, u, w)
		&"profile":
			_profile(c, u, w)
		_:
			draw_circle(c, u * 0.2, color)


## City map with three pins.
func _board(c: Vector2, u: float, w: float) -> void:
	var r: Rect2 = Rect2(c - Vector2(u, u) * 0.62, Vector2(u, u) * 1.24)
	draw_rect(r, Color(color, 0.55), false, w)
	draw_line(r.position + Vector2(0, r.size.y * 0.4), r.end - Vector2(0, r.size.y * 0.45), Color(color, 0.35), w)
	draw_line(r.position + Vector2(r.size.x * 0.35, 0), r.position + Vector2(r.size.x * 0.55, r.size.y), Color(color, 0.35), w)
	for p: Vector2 in [Vector2(-0.3, -0.25), Vector2(0.28, -0.05), Vector2(-0.05, 0.3)]:
		draw_circle(c + p * u, u * 0.11, color)


## Blueprint sheet with a route.
func _planning(c: Vector2, u: float, w: float) -> void:
	var r: Rect2 = Rect2(c - Vector2(u * 0.66, u * 0.5), Vector2(u * 1.32, u))
	draw_rect(r, Color(color, 0.55), false, w)
	var route: PackedVector2Array = PackedVector2Array([r.position + Vector2(u * 0.15, u * 0.8),
			r.position + Vector2(u * 0.5, u * 0.8), r.position + Vector2(u * 0.5, u * 0.3), r.position + Vector2(u * 1.0, u * 0.3)])
	draw_polyline(route, color, w * 1.2, true)
	draw_circle(route[route.size() - 1], u * 0.1, color)


## Rifle silhouette (receiver, barrel, stock, magazine).
func _armory(c: Vector2, u: float, w: float) -> void:
	var body: PackedVector2Array = PackedVector2Array([
		c + Vector2(-0.8, -0.12) * u, c + Vector2(0.15, -0.12) * u, c + Vector2(0.15, -0.2) * u,
		c + Vector2(0.45, -0.2) * u, c + Vector2(0.45, -0.1) * u, c + Vector2(0.85, -0.1) * u,
		c + Vector2(0.85, -0.02) * u, c + Vector2(0.3, -0.02) * u, c + Vector2(0.2, 0.1) * u,
		c + Vector2(-0.35, 0.1) * u, c + Vector2(-0.8, 0.2) * u])
	draw_colored_polygon(body, Color(color, 0.85))
	draw_rect(Rect2(c + Vector2(-0.05, 0.1) * u, Vector2(0.16, 0.36) * u), color)
	draw_line(c + Vector2(-0.3, 0.1) * u, c + Vector2(-0.38, 0.36) * u, color, w * 1.6)


## Mask face: outline, two eye slits.
func _masks(c: Vector2, u: float, w: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(25):
		var a: float = TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(a) * 0.52, sin(a) * 0.66 + (0.08 if sin(a) > 0.0 else 0.0)) * u)
	draw_polyline(pts, color, w * 1.2, true)
	for sx: float in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(sx * 0.22, -0.14) * u
		draw_colored_polygon(PackedVector2Array([e + Vector2(-0.16 * sx, -0.06) * u, e + Vector2(0.16 * sx, 0.02) * u,
				e + Vector2(0.13 * sx, 0.11) * u, e + Vector2(-0.14 * sx, 0.07) * u]), color)
	draw_line(c + Vector2(0, 0.0) * u, c + Vector2(0, 0.22) * u, Color(color, 0.6), w)


## Target rings with a cross.
func _range(c: Vector2, u: float, w: float) -> void:
	for f: float in [0.62, 0.4]:
		draw_arc(c, u * f, 0.0, TAU, 40, Color(color, 0.7), w, true)
	draw_circle(c, u * 0.14, color)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + d * u * 0.68, c + d * u * 0.85, color, w)


## Crew net: four heads on a link line (co-op lobby, B4-11).
func _crew(c: Vector2, u: float, w: float) -> void:
	draw_line(c + Vector2(-0.78, 0.36) * u, c + Vector2(0.78, 0.36) * u, Color(color, 0.55), w)
	for i: int in range(4):
		var x: float = -0.6 + float(i) * 0.4
		var head: Vector2 = c + Vector2(x, -0.12) * u
		draw_circle(head, u * 0.15, color)
		draw_arc(head + Vector2(0, 0.3) * u, u * 0.17, PI, TAU, 12, Color(color, 0.85), w, true)
		draw_line(head + Vector2(0, 0.3) * u, c + Vector2(x, 0.34) * u, Color(color, 0.55), w)


## Two beamed eighth notes (jukebox, B5-03).
func _jukebox(c: Vector2, u: float, w: float) -> void:
	var heads: Array[Vector2] = [c + Vector2(-0.38, 0.38) * u, c + Vector2(0.34, 0.26) * u]
	for h: Vector2 in heads:
		draw_circle(h, u * 0.16, color)
		draw_line(h + Vector2(u * 0.14, 0), h + Vector2(u * 0.14, -u * 0.82), color, w * 1.2)
	var a: Vector2 = heads[0] + Vector2(u * 0.14, -u * 0.82)
	var b: Vector2 = heads[1] + Vector2(u * 0.14, -u * 0.82)
	draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, u * 0.16), a + Vector2(0, u * 0.16)]), color)
	draw_arc(c, u * 0.78, PI * 1.05, PI * 1.35, 10, Color(color, 0.45), w, true)


## Five-point star in a ring (Notoriety, the Old Press station, B6-06 / QC-46).
func _notoriety(c: Vector2, u: float, w: float) -> void:
	draw_arc(c, u * 0.78, 0.0, TAU, 40, Color(color, 0.55), w, true)
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(10):
		var a: float = -PI * 0.5 + PI * float(i) / 5.0
		var r: float = 0.56 if i % 2 == 0 else 0.23
		pts.append(c + Vector2(cos(a), sin(a)) * u * r)
	draw_colored_polygon(pts, color)


## Dossier card: a head-and-shoulders portrait beside record lines (career screen, hub_map v1.1).
func _profile(c: Vector2, u: float, w: float) -> void:
	var r: Rect2 = Rect2(c - Vector2(u * 0.72, u * 0.52), Vector2(u * 1.44, u * 1.04))
	draw_rect(r, Color(color, 0.55), false, w)
	var head: Vector2 = c + Vector2(-0.34, -0.1) * u
	draw_circle(head, u * 0.16, color)
	draw_arc(head + Vector2(0, 0.42) * u, u * 0.24, PI, TAU, 14, color, w * 1.4, true)
	for i: int in range(3):
		var y: float = -0.22 + float(i) * 0.22
		var x1: float = 0.5 if i == 1 else 0.56
		draw_line(c + Vector2(0.04, y) * u, c + Vector2(x1, y) * u, Color(color, 0.85 if i == 0 else 0.5), w)
