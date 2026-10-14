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
## Lead queue (c): marker glyph per objective kind (kind_for); the current marker pulses for PULSE_S
## when the current objective changes.
const PULSE_S: float = 0.8
const KINDS: Dictionary = {
	"escape": &"escape", "casing": &"eye", "keycard": &"card", "code": &"card", "cage_code": &"card",
	"door": &"door", "gate": &"door", "breach": &"door", "safe": &"safe", "vault": &"safe", "strongroom": &"safe",
	"drill": &"drill", "time_lock": &"drill", "hack": &"laptop", "laptop": &"laptop", "server": &"laptop",
	"secure": &"bag", "loot": &"bag", "drives": &"bag", "paintings": &"bag", "product": &"bag",
	"containers": &"bag", "depository": &"bag", "cage": &"bag", "count_cage": &"bag", "burn": &"fire",
}

## Last drawn markers: [{id, pos: Vector2 (local), clamped: bool, distance_m: float, label: String}] (tests).
var drawn: Array[Dictionary] = []
## Lead h02 note: only the current step's marker unless this is on (Hud sets it while Tab is held).
var show_all: bool = false:
	set(v):
		if v != show_all:
			show_all = v
			refresh()
var _font: Font
var _pulse: float = 0.0
var _last_current: StringName = &""


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


func _process(delta: float) -> void:
	var cur: StringName = current_objective_id()
	if cur != _last_current:
		_pulse = PULSE_S if _last_current != &"" and cur != &"" and UiTokens.motion_ok() else 0.0
		_last_current = cur
	_pulse = maxf(_pulse - delta, 0.0)
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


## Glyph kind for objective `id` / `text_key` ("objective.glasshouse.workshop_door" -> &"door"):
## the longest KINDS key the id's last part contains; &"" = the plain diamond.
static func kind_for(m: Dictionary) -> StringName:
	var tail: String = String(m.get("id", ""))
	if tail == "":
		tail = String(m.get("text_key", "")).get_slice(".", 2)
	var best: String = ""
	for k: String in KINDS:
		if tail.contains(k) and k.length() > best.length():
			best = k
	return KINDS[best] as StringName if best != "" else &""


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
		drawn.append({"id": id, "pos": placed[0] as Vector2, "clamped": bool(placed[1]), "kind": kind_for(m),
				"distance_m": cam.global_position.distance_to(world), "current": current == &"" or id == current,
				"label": ObjectivesPanel.objective_text(o)})


func _draw() -> void:
	var fs: int = UiTokens.FONT_SMALL
	for d: Dictionary in drawn:
		# PO-4: the panel's current objective gets the full badge (ring + glyph); other live steps a small dot.
		var cur: bool = bool(d["current"])
		var c: Vector2 = d["pos"] as Vector2
		if not cur:
			draw_circle(c, SIZE * 0.45, Color(UiTokens.INK_0, 0.9))
			draw_circle(c, SIZE * 0.35, Color(UiTokens.PAPER_DIM, 0.8))
			_text(c + Vector2(0, SIZE + fs - 2), UiText.t(&"ui.hud.marker_distance", {"m": roundi(float(d["distance_m"]))}),
					fs, UiTokens.PAPER_DIM)
			continue
		var r: float = SIZE * 1.6
		var grow: float = 1.0 + 0.35 * sin(clampf(_pulse / PULSE_S, 0.0, 1.0) * PI)  # pulse on a new step
		draw_circle(c, r * grow, Color(UiTokens.INK_0, 0.85))
		draw_arc(c, r * grow, 0.0, TAU, 28, tweak.objective_color, 2.5, true)
		_glyph(StringName(d.get("kind", &"")), c, r * 0.55 * grow, tweak.objective_color)
		var dist: String = UiText.t(&"ui.hud.marker_distance", {"m": roundi(float(d["distance_m"]))})
		_text(c + Vector2(0, r * grow + fs + 2), dist, fs, UiTokens.PAPER)
		if not bool(d["clamped"]):
			_text(c + Vector2(0, -r * grow - 8), String(d["label"]), fs, UiTokens.PAPER)


## Objective glyph of `kind` around `c` (half-size `u`), simple strokes in `col`.
func _glyph(kind: StringName, c: Vector2, u: float, col: Color) -> void:
	var w: float = 2.0
	match kind:
		&"escape":  # an arrow out
			draw_line(c + Vector2(-0.8, 0) * u, c + Vector2(0.7, 0) * u, col, w)
			draw_polyline(PackedVector2Array([c + Vector2(0.2, -0.5) * u, c + Vector2(0.8, 0) * u,
					c + Vector2(0.2, 0.5) * u]), col, w)
		&"eye":
			draw_arc(c + Vector2(0, 0.45) * u, 0.9 * u, PI * 1.2, PI * 1.8, 10, col, w)
			draw_arc(c - Vector2(0, 0.45) * u, 0.9 * u, PI * 0.2, PI * 0.8, 10, col, w)
			draw_circle(c, 0.25 * u, col)
		&"card":
			draw_rect(Rect2(c - Vector2(0.8, 0.5) * u, Vector2(1.6, 1.0) * u), col, false, w)
			draw_line(c + Vector2(-0.8, -0.15) * u, c + Vector2(0.8, -0.15) * u, col, w)
		&"door":
			draw_rect(Rect2(c - Vector2(0.45, 0.8) * u, Vector2(0.9, 1.6) * u), col, false, w)
			draw_circle(c + Vector2(0.2, 0.05) * u, 0.1 * u, col)
		&"safe":
			draw_rect(Rect2(c - Vector2(0.75, 0.75) * u, Vector2(1.5, 1.5) * u), col, false, w)
			draw_arc(c, 0.35 * u, 0.0, TAU, 12, col, w)
		&"drill":
			draw_rect(Rect2(c + Vector2(-0.8, -0.35) * u, Vector2(1.0, 0.7) * u), col, false, w)
			draw_line(c + Vector2(0.2, 0) * u, c + Vector2(0.85, 0) * u, col, w)
		&"laptop":
			draw_rect(Rect2(c + Vector2(-0.65, -0.65) * u, Vector2(1.3, 0.9) * u), col, false, w)
			draw_line(c + Vector2(-0.85, 0.5) * u, c + Vector2(0.85, 0.5) * u, col, w)
		&"bag":
			draw_rect(Rect2(c + Vector2(-0.7, -0.35) * u, Vector2(1.4, 1.0) * u), col, false, w)
			draw_arc(c + Vector2(0, -0.35) * u, 0.35 * u, PI, TAU, 8, col, w)
		&"fire":
			draw_polyline(PackedVector2Array([c + Vector2(-0.5, 0.7) * u, c + Vector2(-0.6, 0.0) * u,
					c + Vector2(-0.1, -0.8) * u, c + Vector2(0.1, -0.2) * u, c + Vector2(0.35, -0.5) * u,
					c + Vector2(0.6, 0.1) * u, c + Vector2(0.5, 0.7) * u, c + Vector2(-0.5, 0.7) * u]), col, w)
		_:
			var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0, -u), c + Vector2(u, 0), c + Vector2(0, u),
					c + Vector2(-u, 0)])
			draw_colored_polygon(pts, col)


func _text(center: Vector2, s: String, fs: int, col: Color) -> void:
	var w: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at: Vector2 = center - Vector2(w * 0.5, 0)
	draw_string_outline(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 1))
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
