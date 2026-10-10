## Detection chevrons around the crosshair (pd2_fidelity S2.1): one per observer in
## model.detection, pointing toward the observer's world_pos relative to the local camera
## (get_viewport().get_camera_3d()). Blue below 0.5, orange from 0.5, red at 1.0 (HudTweak).
class_name DetectionChevrons
extends HudWidget

## Last drawn chevrons: [{ "observer_net_id", "angle" (rad, 0 = straight ahead/up, clockwise),
## "value", "color" }]. Exposed for tests.
var chevrons: Array[Dictionary] = []


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func watched_signals() -> Array[StringName]:
	return [&"detection_changed"]


func refresh() -> void:
	chevrons.clear()
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	for ind: Dictionary in prop(&"detection", []) as Array:
		var value: float = float(ind.get("value", 0.0))
		if value < tweak.detection_min_visible:
			continue
		chevrons.append({
			"observer_net_id": int(ind.get("observer_net_id", 0)),
			"angle": screen_angle(cam, ind.get("world_pos", Vector3.ZERO) as Vector3),
			"value": value,
			"color": color_for(value),
		})
	set_process(not chevrons.is_empty())
	queue_redraw()


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
	var center: Vector2 = size * 0.5
	var r: float = tweak.chevron_radius_px
	var s: float = tweak.chevron_size_px
	for c: Dictionary in chevrons:
		var a: float = float(c["angle"])
		var dir: Vector2 = Vector2(sin(a), -cos(a))
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var grow: float = 0.6 + 0.4 * clampf(float(c["value"]), 0.0, 1.0)
		var tip: Vector2 = center + dir * (r + s * grow)
		var base: Vector2 = center + dir * r
		var pts: PackedVector2Array = PackedVector2Array([tip, base + side * s * 0.7 * grow, base - side * s * 0.7 * grow])
		var col: Color = c["color"] as Color
		draw_colored_polygon(pts, col)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.6), 2.0)
