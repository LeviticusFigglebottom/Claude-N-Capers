## PO6-20: a waypoint over every guard whose pager is live: an amber pager badge at the body with the time left
## (UiText.clock) under it, and a cyan ring filling while someone answers. Off-screen or behind the camera it clamps
## to the screen edge (ObjectiveMarkers.clamp_to_edge), so a pager in the next room is found fast. Owner: ENV B.
## Data: model.pagers rows [{pager_id, time_left_s, answering, progress[, guard_net_id, world_pos]}] (ui_hud.md);
## without guard_net_id / world_pos in a row the guard comes from EventBus.pager_started(pager_id, guard_net_id) and its
## position from Ids.lookup, HudTweak.pager_marker_height_m above the body's origin.
class_name PagerWaypoints
extends HudWidget

const SIZE: float = 15.0

## Last drawn: [{pager_id, pos: Vector2 (local), clamped: bool, time_text, answering, progress}] (tests).
var drawn: Array[Dictionary] = []
## pager_id -> guard net id (EventBus.pager_started).
var guards: Dictionary = {}
var _font: Font


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = UiTokens.font_caps()


func _enter_tree() -> void:
	EventBus.pager_started.connect(_on_pager_started)
	EventBus.pager_answered.connect(_on_pager_done)
	EventBus.pager_failed.connect(_on_pager_failed)


func _exit_tree() -> void:
	EventBus.pager_started.disconnect(_on_pager_started)
	EventBus.pager_answered.disconnect(_on_pager_done)
	EventBus.pager_failed.disconnect(_on_pager_failed)
	guards.clear()


func watched_signals() -> Array[StringName]:
	return [&"pagers_changed"]


func refresh() -> void:
	var live: bool = not (prop(&"pagers", []) as Array).is_empty()
	if not live:
		drawn.clear()
	set_process(live)
	queue_redraw()


func _process(_delta: float) -> void:
	_layout(prop(&"pagers", []) as Array)
	queue_redraw()


## World point of pager row `p`, or null when the guard is unknown / gone.
func world_pos(p: Dictionary) -> Variant:
	if p.get("world_pos", null) is Vector3:
		return p["world_pos"]
	var gid: int = int(p.get("guard_net_id", guards.get(int(p.get("pager_id", -1)), -1)))
	var n: Node3D = Ids.lookup(gid) as Node3D if gid >= 0 else null
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return null
	return n.global_position + Vector3.UP * tweak.pager_marker_height_m


func _layout(rows: Array) -> void:
	drawn.clear()
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var area: Rect2 = Rect2(Vector2.ZERO, size)
	for v: Variant in rows:
		if not v is Dictionary:
			continue
		var p: Dictionary = v as Dictionary
		var wp: Variant = world_pos(p)
		if not wp is Vector3:
			continue
		var world: Vector3 = wp as Vector3
		var placed: Array = ObjectiveMarkers.clamp_to_edge(to_local * cam.unproject_position(world),
				cam.is_position_behind(world), area)
		drawn.append({"pager_id": int(p.get("pager_id", -1)), "pos": placed[0] as Vector2, "clamped": bool(placed[1]),
				"time_text": UiText.clock(float(p.get("time_left_s", 0.0))), "answering": bool(p.get("answering", false)),
				"progress": clampf(float(p.get("progress", 0.0)), 0.0, 1.0)})


func _draw() -> void:
	var fs: int = UiTokens.FONT_SMALL
	for d: Dictionary in drawn:
		var c: Vector2 = d["pos"] as Vector2
		draw_circle(c, SIZE * 1.4, Color(UiTokens.INK_0, 0.85))
		draw_arc(c, SIZE * 1.4, 0.0, TAU, 28, tweak.pager_color, 2.5, true)
		# Pager glyph: a small handset with a screen.
		draw_rect(Rect2(c - Vector2(0.55, 0.75) * SIZE, Vector2(1.1, 1.5) * SIZE), tweak.pager_color, false, 2.0)
		draw_rect(Rect2(c - Vector2(0.35, 0.5) * SIZE, Vector2(0.7, 0.45) * SIZE), tweak.pager_color)
		if bool(d["answering"]):
			draw_arc(c, SIZE * 1.8, -PI * 0.5, -PI * 0.5 + TAU * float(d["progress"]), 32, UiTokens.CYAN, 3.0, true)
		var s: String = String(d["time_text"])
		var w: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at: Vector2 = c + Vector2(-w * 0.5, SIZE * 1.4 + fs + 4.0)
		draw_string_outline(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 1))
		draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tweak.pager_color)


func _on_pager_started(pager_id: int, guard_net_id: int) -> void:
	guards[pager_id] = guard_net_id


func _on_pager_done(pager_id: int, _crew_slot: int, _answered_total: int) -> void:
	guards.erase(pager_id)


func _on_pager_failed(pager_id: int, _reason: StringName) -> void:
	guards.erase(pager_id)
