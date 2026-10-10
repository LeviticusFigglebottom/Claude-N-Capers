## Marked targets (pd2_fidelity S2.9): a diamond above each entry of model.marked_targets
## ([{net_id, world_pos, kind}], ui_hud.md v1.1), projected through the local camera
## (get_viewport().get_camera_3d()). Targets behind the camera are not drawn. A simple stand-in until
## the crew-wide outline (S2.9, ENV C shader) lands.
class_name MarkedTargets
extends HudWidget

## Last drawn markers: [{ "net_id", "screen_pos": Vector2, "kind" }]. Exposed for tests.
var markers: Array[Dictionary] = []


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func watched_signals() -> Array[StringName]:
	return [&"marked_targets_changed"]


func refresh() -> void:
	markers.clear()
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var entries: Array = prop(&"marked_targets", []) as Array
	for e: Dictionary in entries:
		var p: Vector3 = (e.get("world_pos", Vector3.ZERO) as Vector3) + Vector3.UP * tweak.mark_height_m
		if cam == null or cam.is_position_behind(p):
			continue
		markers.append({"net_id": int(e.get("net_id", 0)), "screen_pos": cam.unproject_position(p),
				"kind": StringName(e.get("kind", &""))})
	set_process(not entries.is_empty())
	queue_redraw()


func _process(_delta: float) -> void:
	refresh()  # the camera moves every frame while marks exist


func _draw() -> void:
	var s: float = tweak.mark_size_px
	# unproject_position gives viewport pixels; this control fills the HUD (canvas stretch).
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
	for m: Dictionary in markers:
		var c: Vector2 = to_local * (m["screen_pos"] as Vector2)
		var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, 0),
				c + Vector2(0, s), c + Vector2(-s * 0.7, 0)])
		draw_colored_polygon(pts, tweak.mark_color)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.7), 2.0)
