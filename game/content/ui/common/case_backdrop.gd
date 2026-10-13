## PO-4 menu backdrop (docs/design/ui/style.md §1 "Case File"): the INK_0 fill plus, drawn in code, a
## faint blueprint grid, a soft top light and crop marks in the safe-area corners.
## A ColorRect, so callers dim it through `color.a` (the 3D safehouse behind a screen); the
## decoration fades with it. Owner: ENV B.
class_name CaseBackdrop
extends ColorRect

const GRID: float = 64.0
const MARK_LEN: float = 28.0
const MARK_INSET: float = 36.0


func _init() -> void:
	color = UiTokens.INK_0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var a: float = color.a
	var w: float = size.x
	var h: float = size.y
	# Top light: a few stacked translucent bands, brighter at the top centre.
	for i: int in range(6):
		var f: float = float(i) / 6.0
		var band: Rect2 = Rect2(w * (0.1 + f * 0.15), 0.0, w * (0.8 - f * 0.3), h * (0.55 - f * 0.08))
		draw_rect(band, Color(UiTokens.INK_2, 0.06 * a))
	var line: Color = Color(UiTokens.LINE, 0.22 * a)
	var x: float = GRID
	while x < w:
		draw_line(Vector2(x, 0), Vector2(x, h), line, 1.0)
		x += GRID
	var y: float = GRID
	while y < h:
		draw_line(Vector2(0, y), Vector2(w, y), line, 1.0)
		y += GRID
	var mark: Color = Color(UiTokens.PAPER_MUTE, 0.7 * a)
	for c: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p: Vector2 = Vector2(lerpf(MARK_INSET, w - MARK_INSET, c.x), lerpf(MARK_INSET, h - MARK_INSET, c.y))
		var dx: float = MARK_LEN if c.x == 0.0 else -MARK_LEN
		var dy: float = MARK_LEN if c.y == 0.0 else -MARK_LEN
		draw_line(p, p + Vector2(dx, 0), mark, 2.0)
		draw_line(p, p + Vector2(0, dy), mark, 2.0)
