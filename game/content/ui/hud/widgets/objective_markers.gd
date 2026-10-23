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
## P fresh-eyes #8: a marker clamped to the bottom edge sat on the ammo / inventory cluster ("27 / 120")
## and at the top on the objective / assault band. Clamped markers keep out of the HUD's bands: top and
## bottom insets clear them (with the marker's distance line under it), the sides keep EDGE_INSET.
const EDGE_INSET_TOP: float = 150.0
const EDGE_INSET_BOTTOM: float = 200.0
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
## Canvas rect where marker text is not drawn (the Tab sheet while it shows; Hud sets it). Badges still draw.
var avoid: Rect2 = Rect2():
	set(v):
		if v != avoid:
			avoid = v
			queue_redraw()
## Canvas rect of the subtitle box while it shows (Hud sets it; empty = none). LEAD r230 (gh_camera_02): the box sat
## over an on-screen marker ("8 m"); a marker that would land under it is lifted above the box.
var subtitle_band: Rect2 = Rect2()
## LEAD r308 (AH gear prompt: "Get the gear the insider left" printed under "Hold F to pick up your gear"): the
## interaction prompt's canvas rect while it shows (Hud sets it; empty = none). A marker label there is not drawn; the
## badge and its distance stay.
var prompt_band: Rect2 = Rect2():
	set(v):
		if v != prompt_band:
			prompt_band = v
			queue_redraw()
## GPU-19: the top-centre banner stack (assault banner + boss panel; global rect, Hud sets it): badges under it step
## below it (below_band).
var top_band: Rect2 = Rect2()
var _font: Font
var _scrim: StyleBoxFlat = UiBuild.label_scrim()
var _pulse: float = 0.0
var _last_current: StringName = &""
## Perf (lead): marker labels per objective id (cleared on refresh, i.e. when objectives change) and
## distance strings per whole metre, so a frame formats no text.
var _labels: Dictionary = {}
var _distances: Dictionary = {}


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = UiTokens.font_caps()


func watched_signals() -> Array[StringName]:
	return [&"objective_markers_changed", &"player_mode_changed", &"objectives_changed"]


func refresh() -> void:
	_labels.clear()
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
	var inner: Rect2 = area.grow_individual(-EDGE_INSET, -EDGE_INSET_TOP, -EDGE_INSET, -EDGE_INSET_BOTTOM)
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


## `p` lifted above `band` (local) when the badge and its distance line would overlap it; otherwise `p`.
## GPU-19 (3440x1440, OF wave 2): `p` (a badge with its label above it) moved below `band` when it would sit under it.
static func below_band(p: Vector2, band: Rect2) -> Vector2:
	if not band.has_area():
		return p
	var reach: float = SIZE * 1.6 + UiTokens.FONT_SMALL + 6.0  # badge radius + the label line above it
	if p.x < band.position.x - SIZE * 1.6 or p.x > band.end.x + SIZE * 1.6:
		return p
	if p.y + SIZE * 1.6 < band.position.y or p.y - reach > band.end.y:
		return p
	return Vector2(p.x, band.end.y + reach)


static func clear_of_band(p: Vector2, band: Rect2) -> Vector2:
	if not band.has_area():
		return p
	var reach: float = SIZE * 1.6 + UiTokens.FONT_SMALL + 6.0  # badge radius + the distance line under it
	if p.x < band.position.x - SIZE * 1.6 or p.x > band.end.x + SIZE * 1.6:
		return p
	if p.y + reach < band.position.y or p.y - SIZE * 1.6 > band.end.y:
		return p
	return Vector2(p.x, band.position.y - reach)


func _layout(entries: Array) -> void:
	drawn.clear()
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var area: Rect2 = Rect2(Vector2.ZERO, size)
	var current: StringName = current_objective_id()
	for m: Dictionary in entries:
		if int(m.get("state", Enums.ObjectiveState.ACTIVE)) != Enums.ObjectiveState.ACTIVE or not shows(m):
			continue
		var world: Vector3 = m.get("position", Vector3.ZERO) as Vector3
		var behind: bool = cam.is_position_behind(world)
		var local: Vector2 = to_local * cam.unproject_position(world)
		var placed: Array = clamp_to_edge(local, behind, area)
		placed[0] = clear_of_band(placed[0] as Vector2, to_local * subtitle_band if subtitle_band.has_area() else Rect2())
		placed[0] = below_band(placed[0] as Vector2, to_local * top_band if top_band.has_area() else Rect2())
		var id: StringName = StringName(m.get("id", &""))
		if not show_all and current != &"" and id != current:
			continue
		if not _labels.has(id):
			var o: Dictionary = {"text_key": m.get("text_key", &""), "args": {}}
			for obj: Dictionary in prop(&"objectives", []) as Array:
				if StringName(obj.get("id", &"")) == id:
					o = obj
					break
			_labels[id] = ObjectivesPanel.objective_text(o)
		drawn.append({"id": id, "pos": placed[0] as Vector2, "clamped": bool(placed[1]), "kind": kind_for(m),
				"distance_m": cam.global_position.distance_to(world), "current": current == &"" or id == current,
				"label": _labels[id]})


func _draw() -> void:
	var fs: int = UiTokens.FONT_SMALL
	var shield: Rect2 = get_global_transform_with_canvas().affine_inverse() * avoid if avoid.has_area() else Rect2()
	var dot_labels: Array[Rect2] = []  # GH real-input Tab shot: far dots stacked "21 m / 15 m / 13 m"
	for d: Dictionary in drawn:
		# Lead (flow capture): a marker over the Tab sheet hid its text; markers inside the sheet are not drawn there.
		if shield.has_area() and shield.grow(SIZE * 1.6).has_point(d["pos"] as Vector2):
			continue
		# PO-4: the panel's current objective gets the full badge (ring + glyph); other live steps a small dot.
		var cur: bool = bool(d["current"])
		var c: Vector2 = d["pos"] as Vector2
		if not cur:
			draw_circle(c, SIZE * 0.45, Color(UiTokens.INK_0, 0.9))
			draw_circle(c, SIZE * 0.35, Color(UiTokens.PAPER_DIM, 0.8))
			var lr: Rect2 = Rect2(c + Vector2(-SIZE * 2.5, SIZE - 2), Vector2(SIZE * 5.0, fs + 2))
			if not label_overlaps(lr, dot_labels):  # a dot whose distance would sit on another's keeps only the dot
				dot_labels.append(lr)
				_text(c + Vector2(0, SIZE + fs - 2), _distance_text(float(d["distance_m"])), fs, UiTokens.PAPER_DIM)
			continue
		var r: float = SIZE * 1.6
		var grow: float = 1.0 + 0.35 * sin(clampf(_pulse / PULSE_S, 0.0, 1.0) * PI)  # pulse on a new step
		draw_circle(c, r * grow, Color(UiTokens.INK_0, 0.85))
		draw_arc(c, r * grow, 0.0, TAU, 28, tweak.objective_color, 2.5, true)
		_glyph(StringName(d.get("kind", &"")), c, r * 0.55 * grow, tweak.objective_color)
		var dist: String = _distance_text(float(d["distance_m"]))
		_text(c + Vector2(0, r * grow + fs + 2), dist, fs, UiTokens.PAPER)
		if not bool(d["clamped"]):
			_text(c + Vector2(0, -r * grow - 8), String(d["label"]), fs, UiTokens.PAPER)


static func label_overlaps(r: Rect2, taken: Array[Rect2]) -> bool:
	for t: Rect2 in taken:
		if t.intersects(r):
			return true
	return false


## "12 m" for a distance, formatted once per whole metre.
func _distance_text(m: float) -> String:
	var k: int = roundi(m)
	if not _distances.has(k):
		_distances[k] = UiText.t(&"ui.hud.marker_distance", {"m": k})
	return _distances[k]


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


## r252 GPU loud run: a badge clamped to the screen edge drew its centred label half off-screen ("URRET VAN"); the
## label x stays inside [margin, width - margin] (the badge itself stays where it is).
static func label_x(center_x: float, w: float, width: float, margin: float = 6.0) -> float:
	return clampf(center_x - w * 0.5, margin, maxf(margin, width - w - margin))


## Lane 2 audit: over the Tab sheet a label crossed its text (LOOT SECURED); LEAD r308: the same under the interaction
## prompt. A label box that meets any band (local rects; empty = none) is not drawn, only the badge.
static func label_hidden_by(box: Rect2, bands: Array[Rect2]) -> bool:
	for band: Rect2 in bands:
		if band.has_area() and band.intersects(box):
			return true
	return false


func _text(center: Vector2, s: String, fs: int, col: Color) -> void:
	var w: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at: Vector2 = Vector2(label_x(center.x, w, size.x, UiBuild.LABEL_SCRIM_PAD.x + 2.0), center.y)
	var inv: Transform2D = get_global_transform_with_canvas().affine_inverse()
	if label_hidden_by(Rect2(at - Vector2(0, fs), Vector2(w, fs + 4)), [inv * avoid, inv * prompt_band] as Array[Rect2]):
		return
	# r249 contrast ruling: a rounded scrim behind the label (2.0:1 fill vs the OF stone without it).
	var asc: float = _font.get_ascent(fs)
	var pad: Vector2 = UiBuild.LABEL_SCRIM_PAD
	draw_style_box(_scrim, Rect2(at - Vector2(pad.x, asc + pad.y), Vector2(w, asc + _font.get_descent(fs)) + pad * 2.0))
	draw_string_outline(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 1))
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
