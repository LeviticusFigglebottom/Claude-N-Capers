## D-128 (PO playtest): PD2's detection indicator. It replaces the S2.1 chevrons.
## * Over each observer in model.detection (guards, civilians, police, cameras): a ring that fills clockwise from the top
##   with the meter, "?" inside while it fills and a red "!" at detected (value >= HudTweak.detection_red_at). Off-screen
##   or behind the camera: no ring (the crosshair arc shows the direction).
## * Around the crosshair: one arc per observer, centred on the observer's direction, filling the same way. Live GH/SL
##   check (r229): an observer whose own ring lands on the arc band (straight ahead at mid range) gets no arc, so the
##   two never stack; its ring marks the spot.
## * Colours: HudTweak.detection_blue (white by default; the "filling" colour) below detection_orange_from, then orange,
##   then red; the accessibility palettes override all three.
## * No indicator while heist_phase is LOUD (PD2: detection ends with the alarm).
## * ui_hud v1.17: a row may carry `state` (&"curious" / &"investigating", S3.4). Such a row shows the "?"
##   ring even at value 0 (an NPC checking a noise); the crosshair arc needs a value above zero.
class_name DetectionRings
extends HudWidget

## Row states that show the "?" ring at any value.
const QUESTION_STATES: Array[StringName] = [&"curious", &"investigating"]

## Last drawn indicators (tests): [{"observer_net_id", "kind", "value", "state", "color", "glyph" ("?" / "!"),
## "angle" (rad, 0 = straight ahead/up, clockwise), "on_screen" (bool), "ring_pos" (Vector2, local), "arc" (bool)}].
var rings: Array[Dictionary] = []


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func watched_signals() -> Array[StringName]:
	return [&"detection_changed", &"changed"]  # changed: heist_phase (no rings once loud)


func refresh() -> void:
	rings.clear()
	# LEAD r229 crowding pass: PD2 drops detection once the alarm is up; a LOUD phase draws no ring or arc.
	if int(prop(&"heist_phase", -1)) == Enums.HeistPhase.LOUD:
		set_process(false)
		queue_redraw()
		return
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	for ind: Dictionary in prop(&"detection", []) as Array:
		var value: float = clampf(float(ind.get("value", 0.0)), 0.0, 1.0)
		var state: StringName = StringName(ind.get("state", &""))
		var asking: bool = QUESTION_STATES.has(state)
		if value < tweak.detection_min_visible and not asking:
			continue
		var kind: int = int(ind.get("kind", Enums.ObserverKind.GUARD))
		var wp: Vector3 = ind.get("world_pos", Vector3.ZERO) as Vector3
		var anchor: Vector3 = wp + Vector3.UP * (tweak.ring_camera_offset_m if kind == Enums.ObserverKind.CAMERA
				else tweak.ring_head_offset_m)
		var row: Dictionary = {
			"observer_net_id": int(ind.get("observer_net_id", 0)), "kind": kind, "value": value, "state": state,
			"color": color_for(value), "glyph": "!" if value >= tweak.detection_red_at else "?",
			"angle": screen_angle(cam, wp), "on_screen": false, "ring_pos": Vector2.ZERO,
			"arc": value >= tweak.detection_min_visible,
		}
		if cam != null and not cam.is_position_behind(anchor):
			var p: Vector2 = get_global_transform_with_canvas().affine_inverse() * cam.unproject_position(anchor)  # as DeviceTimers
			var r: float = tweak.ring_radius_px
			if Rect2(Vector2.ZERO, size).grow(-r).has_point(p):
				row["on_screen"] = true
				row["ring_pos"] = p
				if absf(p.distance_to(size * 0.5) - tweak.chevron_radius_px) < arc_clearance():
					row["arc"] = false
		rings.append(row)
	set_process(not rings.is_empty())
	queue_redraw()


## Least distance between a ring's centre and the crosshair arc circle for the two not to touch: the ring's backing
## disc (_ring) plus half the arc's backing stroke (_crosshair_arc) plus a small gap.
func arc_clearance() -> float:
	return tweak.ring_radius_px + tweak.ring_width_px * 0.5 + 2.0 + (tweak.arc_width_px + 4.0) * 0.5 + 4.0


func color_for(value: float) -> Color:
	if value >= tweak.detection_red_at:
		return tweak.detection_red
	if value >= tweak.detection_orange_from:
		return tweak.detection_orange
	return tweak.detection_blue


## Angle on screen toward `world_pos` (0 = up/ahead, PI/2 = right, PI = behind/down).
static func screen_angle(cam: Camera3D, world_pos: Vector3) -> float:
	if cam == null:
		return 0.0
	var local: Vector3 = cam.global_transform.affine_inverse() * world_pos
	return atan2(local.x, -local.z)


func _process(_delta: float) -> void:
	refresh()  # the camera moves every frame while indicators are active


func _draw() -> void:
	var font: Font = UiTokens.font_heading()
	for c: Dictionary in rings:
		var col: Color = c["color"] as Color
		var value: float = float(c["value"])
		if bool(c["arc"]):
			_crosshair_arc(float(c["angle"]), value, col)
		if bool(c["on_screen"]):
			_ring(c["ring_pos"] as Vector2, value, col, String(c["glyph"]), font)


## The world ring: a dark disc, a dim track, the fill clockwise from 12 o'clock on a dark under-stroke (it reads on a
## lit wall or a lamp behind the observer), the glyph in the middle.
func _ring(at: Vector2, value: float, col: Color, glyph: String, font: Font) -> void:
	var r: float = tweak.ring_radius_px
	var w: float = tweak.ring_width_px
	draw_circle(at, r + w * 0.5 + 2.0, Color(0, 0, 0, 0.62))
	draw_arc(at, r, 0.0, TAU, 48, Color(col, 0.35), w, true)
	if value >= 1.0:
		draw_arc(at, r, 0.0, TAU, 48, col, w, true)
	elif value > 0.0:
		var to: float = -PI * 0.5 + TAU * value
		var segs: int = maxi(4, int(48 * value))
		draw_arc(at, r, -PI * 0.5, to, segs, Color(0, 0, 0, 0.7), w + 3.0, true)
		draw_arc(at, r, -PI * 0.5, to, segs, col, w, true)
	var fs: int = int(r * 1.3)
	var gw: Vector2 = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var base: Vector2 = at + Vector2(-gw.x * 0.5, fs * 0.36)
	draw_string_outline(font, base, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
	draw_string(font, base, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## The crosshair arc toward the observer: a dim track over the span, filled clockwise by the meter.
func _crosshair_arc(angle: float, value: float, col: Color) -> void:
	var centre: Vector2 = size * 0.5
	var r: float = tweak.chevron_radius_px
	var half: float = deg_to_rad(tweak.arc_span_deg) * 0.5
	var mid: float = angle - PI * 0.5  # screen_angle 0 = up; draw_arc 0 = +x
	var w: float = tweak.arc_width_px
	draw_arc(centre, r, mid - half, mid + half, 24, Color(0, 0, 0, 0.6), w + 4.0, true)
	draw_arc(centre, r, mid - half, mid + half, 24, Color(col, 0.38), w, true)
	draw_arc(centre, r, mid - half, mid - half + 2.0 * half * value, maxi(3, int(24 * value)), col, w, true)
