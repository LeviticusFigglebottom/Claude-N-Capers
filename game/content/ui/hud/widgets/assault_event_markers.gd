## PO6-17: RNG assault events (turret van, helicopter, breach; EventBus.assault_event_started / ended [R], events.md
## v1.6). Each live event gets a red world marker at its position with its name and distance (clamped to the screen
## edge when off-screen or behind, like ObjectiveMarkers), pulsing for HudTweak.assault_event_pulse_s after it starts.
## `active` also feeds the alert line in the AssaultBanner. Owner: ENV B.
class_name AssaultEventMarkers
extends HudWidget

## Emitted when the set of live events changes (the AssaultBanner shows their names).
signal events_changed(kinds: Array[StringName])

const KIND_KEYS: Dictionary = {
	&"turret_van": &"ui.hud.assault_event.turret_van", &"heli": &"ui.hud.assault_event.heli",
	&"breach": &"ui.hud.assault_event.breach",
}
const SIZE: float = 14.0

## net_id -> {kind: StringName, position: Vector3, age: float}.
var active: Dictionary = {}
## Last drawn: [{net_id, kind, pos: Vector2, clamped, label, distance_m}] (tests).
var drawn: Array[Dictionary] = []
var _font: Font


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = UiTokens.font_caps()


func _enter_tree() -> void:
	EventBus.assault_event_started.connect(_on_started)
	EventBus.assault_event_ended.connect(_on_ended)


func _exit_tree() -> void:
	EventBus.assault_event_started.disconnect(_on_started)
	EventBus.assault_event_ended.disconnect(_on_ended)
	active.clear()


static func kind_text(kind: StringName) -> String:
	var key: StringName = KIND_KEYS.get(kind, &"ui.hud.assault_event.unknown") as StringName
	return UiText.t(key)


## Live event kinds, oldest first.
func kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in active:
		out.append(StringName((active[id] as Dictionary)["kind"]))
	return out


func _process(delta: float) -> void:
	for id: Variant in active:
		var e: Dictionary = active[id]
		e["age"] = float(e["age"]) + delta
	_layout()
	queue_redraw()


func _layout() -> void:
	drawn.clear()
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var area: Rect2 = Rect2(Vector2.ZERO, size)
	for id: Variant in active:
		var e: Dictionary = active[id]
		var world: Vector3 = e["position"] as Vector3
		var placed: Array = ObjectiveMarkers.clamp_to_edge(to_local * cam.unproject_position(world),
				cam.is_position_behind(world), area)
		drawn.append({"net_id": int(id), "kind": e["kind"], "pos": placed[0] as Vector2, "clamped": bool(placed[1]),
				"label": kind_text(StringName(e["kind"])), "distance_m": cam.global_position.distance_to(world),
				"pulse": clampf(1.0 - float(e["age"]) / maxf(tweak.assault_event_pulse_s, 0.01), 0.0, 1.0)})


func _draw() -> void:
	var fs: int = UiTokens.FONT_SMALL
	for d: Dictionary in drawn:
		var c: Vector2 = d["pos"] as Vector2
		var grow: float = 1.0 + 0.4 * float(d["pulse"]) * absf(sin(float(d["pulse"]) * TAU * 2.0))
		var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0, -SIZE) * grow, c + Vector2(SIZE, SIZE * 0.8) * grow,
				c + Vector2(-SIZE, SIZE * 0.8) * grow])
		draw_colored_polygon(pts, Color(UiTokens.INK_0, 0.85))
		draw_polyline(pts + PackedVector2Array([pts[0]]), tweak.assault_color, 2.5, true)
		draw_line(c + Vector2(0, -SIZE * 0.45) * grow, c + Vector2(0, SIZE * 0.2) * grow, tweak.assault_color, 2.5)
		draw_circle(c + Vector2(0, SIZE * 0.5) * grow, 1.8 * grow, tweak.assault_color)
		_text(c + Vector2(0, SIZE * grow + fs + 2.0), String(d["label"]), fs, tweak.assault_color)
		_text(c + Vector2(0, SIZE * grow + 2.0 * fs + 4.0),
				UiText.t(&"ui.hud.marker_distance", {"m": roundi(float(d["distance_m"]))}), fs, UiTokens.PAPER)


func _text(center: Vector2, s: String, fs: int, col: Color) -> void:
	var w: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at: Vector2 = center - Vector2(w * 0.5, 0)
	draw_string_outline(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 1))
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _on_started(kind: StringName, net_id: int, position: Vector3) -> void:
	active[net_id] = {"kind": kind, "position": position, "age": 0.0}
	UiSfx.play(UiSfx.ASSAULT_EVENT_WARNING)  # C: 2D UI sting (the world-side van/heli/breach cues are C's CuePlayer)
	set_process(true)
	events_changed.emit(kinds())


func _on_ended(_kind: StringName, net_id: int) -> void:
	active.erase(net_id)
	if active.is_empty():
		drawn.clear()
		set_process(false)
		queue_redraw()
	events_changed.emit(kinds())
