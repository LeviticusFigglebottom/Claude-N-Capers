## Teammate state badge (lead queue b, PD2 crew panel): a glyph for a teammate who needs help, drawn in
## code: downed = a cross, tased = a zigzag, cuffed = two linked rings, custody = bars, cloaker-downed =
## the cross. Around it a ring: red, draining with `bleedout_s` (full at BLEED_REF_S, PD2's bleedout),
## or green, filling with `revive_progress` while someone revives them (crew-row extras asked of ENV A;
## without them only the glyph shows). The row's info line carries the seconds. Owner: ENV B.
class_name CrewStateBadge
extends Control

const BLEED_REF_S: float = 30.0

var state: int = Enums.CrewState.NORMAL
var bleedout_s: float = -1.0
var revive_progress: float = -1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48, 48)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func set_row(row: Dictionary) -> void:
	state = int(row.get("state", Enums.CrewState.NORMAL))
	bleedout_s = float(row.get("bleedout_s", -1.0))
	revive_progress = float(row.get("revive_progress", -1.0))
	visible = state != Enums.CrewState.NORMAL
	tooltip_text = str(ceili(bleedout_s)) if bleedout_s > 0.0 else ""
	queue_redraw()


## Ring fill 0..1 and its colour: revive (green, filling) wins over bleedout (red, draining); -1 = none.
func ring() -> Array:
	if revive_progress >= 0.0:
		return [clampf(revive_progress, 0.0, 1.0), UiTokens.OK]
	if bleedout_s > 0.0:
		return [clampf(bleedout_s / BLEED_REF_S, 0.0, 1.0), UiTokens.ALERT]
	return [-1.0, UiTokens.ALERT]


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 3.0
	draw_circle(c, r, Color(UiTokens.INK_0, 0.7))
	var rg: Array = ring()
	if float(rg[0]) >= 0.0:
		draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, 0.15), 3.0, true)
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * float(rg[0]), 32, rg[1] as Color, 3.0, true)
	var u: float = r * 0.55
	var col: Color = UiTokens.ALERT if state != Enums.CrewState.CUSTODY else UiTokens.PAPER_DIM
	var w: float = 2.5
	match state:
		Enums.CrewState.TASED:
			draw_polyline(PackedVector2Array([c + Vector2(-0.3, -1) * u, c + Vector2(0.25, -0.15) * u,
					c + Vector2(-0.25, 0.15) * u, c + Vector2(0.3, 1) * u]), UiTokens.WARN, w)
		Enums.CrewState.CUFFED:
			draw_arc(c + Vector2(-0.4, 0) * u, 0.45 * u, 0.0, TAU, 12, col, w)
			draw_arc(c + Vector2(0.4, 0) * u, 0.45 * u, 0.0, TAU, 12, col, w)
		Enums.CrewState.CUSTODY:
			for x: float in [-0.75, -0.25, 0.25, 0.75]:
				draw_line(c + Vector2(x, -0.9) * u, c + Vector2(x, 0.9) * u, col, 1.5)
		_:
			draw_line(c + Vector2(0, -0.8) * u, c + Vector2(0, 0.8) * u, col, w + 1.0)
			draw_line(c + Vector2(-0.8, 0) * u, c + Vector2(0.8, 0) * u, col, w + 1.0)
