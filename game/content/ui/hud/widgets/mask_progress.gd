## PO-1 / PO-4: the mask-up progress ring around the crosshair while the player holds mask up
## (LocalHudModel.mask_progress 0..1, an extra property announced through `changed`). Hidden at 0 and
## at 1; a caption under the ring says what is happening. Owner: ENV B.
class_name MaskProgress
extends HudWidget

const RADIUS: float = 34.0
const WIDTH: float = 5.0

var progress: float = 0.0
var caption: Label


func build() -> void:
	caption = UiBuild.float_text(UiBuild.caption(&"ui.hud.masking_up"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption.offset_top = -28.0
	caption.offset_bottom = 0.0
	caption.add_theme_color_override(&"font_color", UiTokens.PAPER)
	add_child(caption)


func watched_signals() -> Array[StringName]:
	return [&"changed", &"masked_changed", &"player_mode_changed"]


func refresh() -> void:
	progress = clampf(float(prop(&"mask_progress", 0.0)), 0.0, 1.0)
	visible = progress > 0.0 and progress < 1.0 and player_mode() != &"masked"
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var c: Vector2 = Vector2(size.x * 0.5, RADIUS + WIDTH)
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(UiTokens.INK_0, 0.55), WIDTH + 2.0, true)
	draw_arc(c, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, UiTokens.PAPER, WIDTH, true)
