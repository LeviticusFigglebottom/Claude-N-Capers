## Objective world markers (ui_hud.md v1.8, D-089; lead lane 5): a brass diamond with the distance
## for every entry of model.objective_markers ([{id, text_key, position: Vector3, state}], ACTIVE only),
## projected through the local camera. Off-screen (or behind the camera) markers clamp to the screen
## edge with an arrow tick toward them; on screen they also show the objective's short name.
## Hidden while casing unless the objective is a casing one (id / text key "casing").
## Owner: ENV B.
class_name ObjectiveMarkers
extends HudWidget

## Diamond half-size and the inset from the screen edge for clamped markers (canvas units).
const SIZE: float = 11.0
const EDGE_INSET: float = 48.0

## Last drawn markers: [{id, pos: Vector2 (local), clamped: bool, distance_m: float, label: String}] (tests).
var drawn: Array[Dictionary] = []
## Lead h02 note: only the current step's marker unless this is on (Hud sets it while Tab is held).
var show_all: bool = false:
	set(v):
		if v != show_all:
			show_all = v
			refresh()
var _font: Font


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = UiTokens.font_caps()


func watched_signals() -> Array[StringName]:
	return [&"objective_markers_changed", &"player_mode_changed", &"objectives_changed"]


func refresh() -> void:
	var entries: Array = prop(&"objective_markers", []) as Array
	set_process(not entries.is_empty())
	_layout(entries)
	queue_redraw()


func _process(_delta: float) -> void:
	_layout(prop(&"objective_markers", []) as Array)  # the camera moves every frame
	queue_redraw()


## True when marker `m` shows in the current player mode.
func shows(m: Dictionary) -> bool:
	if player_mode() != &"casing":
		return true
	return is_casing_objective(m)


## The objective the panel shows (first ACTIVE, not disabled); &"" when none.
func current_objective_id() -> StringName:
	for o: Dictionary in prop(&"objectives", []) as Array:
		if int(o.get("state", Enums.ObjectiveState.ACTIVE)) == Enums.ObjectiveState.ACTIVE \
				and not bool((o.get("args", {}) as Dictionary).get("disabled", false)):
			return StringName(o.get("id", &""))
	return &""


static func is_casing_objective(m: Dictionary) -> bool:
	return String(m.get("id", "")).contains("casing") or String(m.get("text_key", "")).contains("casing")


## Clamps `p` (local canvas position) into `area` shrunk by EDGE_INSET. A point behind the camera is
## mirrored first so it lands on the edge it is "behind". Returns [position: Vector2, clamped: bool].
static func clamp_to_edge(p: Vector2, behind: bool, area: Rect2) -> Array:
	var inner: Rect2 = area.grow(-EDGE_INSET)
	var c: Vector2 = inner.get_center()
	var q: Vector2 = c - (p - c) if behind else p
	if not behind and inner.has_point(q):
		return [q, false]
	var d: Vector2 = q - c
	if d == Vector2.ZERO:
		d = Vector2.DOWN
	var half: Vector2 = inner.size * 0.5
	var t: float = minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
	return [c + d * t, true]


func _layout(entries: Array) -> void:
	drawn.clear()
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var area: Rect2 = Rect2(Vector2.ZERO, size)
	var current: StringName = current_objective_id()
	var args_by_id: Dictionary = {}
	for o: Dictionary in prop(&"objectives", []) as Array:
		args_by_id[StringName(o.get("id", &""))] = o
	for m: Dictionary in entries:
		if int(m.get("state", Enums.ObjectiveState.ACTIVE)) != Enums.ObjectiveState.ACTIVE or not shows(m):
			continue
		var world: Vector3 = m.get("position", Vector3.ZERO) as Vector3
		var behind: bool = cam.is_position_behind(world)
		var local: Vector2 = to_local * cam.unproject_position(world)
		var placed: Array = clamp_to_edge(local, behind, area)
		var id: StringName = StringName(m.get("id", &""))
		if not show_all and current != &"" and id != current:
			continue
		var o: Dictionary = args_by_id.get(id, {"text_key": m.get("text_key", &""), "args": {}}) as Dictionary
		drawn.append({"id": id, "pos": placed[0] as Vector2, "clamped": bool(placed[1]),
				"distance_m": cam.global_position.distance_to(world), "current": current == &"" or id == current,
				"label": ObjectivesPanel.objective_text(o)})


func _draw() -> void:
	var fs: int = UiTokens.FONT_SMALL
	for d: Dictionary in drawn:
		# PO-4: the panel's current objective gets the full marker; other live steps a small dim one.
		var cur: bool = bool(d["current"])
		var r: float = SIZE if cur else SIZE * 0.6
		var c: Vector2 = d["pos"] as Vector2
		var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0),
				c + Vector2(0, r), c + Vector2(-r, 0)])
		draw_colored_polygon(pts, UiTokens.BRASS_HI if cur else Color(UiTokens.PAPER_DIM, 0.75))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(UiTokens.INK_0, 0.9), 2.0)
		var dist: String = UiText.t(&"ui.hud.marker_distance", {"m": roundi(float(d["distance_m"]))})
		_text(c + Vector2(0, r + fs + 2), dist, fs, UiTokens.PAPER if cur else UiTokens.PAPER_DIM)
		if cur and not bool(d["clamped"]):
			_text(c + Vector2(0, -SIZE - 8), String(d["label"]), fs, UiTokens.PAPER)


func _text(center: Vector2, s: String, fs: int, col: Color) -> void:
	var w: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at: Vector2 = center - Vector2(w * 0.5, 0)
	draw_string_outline(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 1))
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
