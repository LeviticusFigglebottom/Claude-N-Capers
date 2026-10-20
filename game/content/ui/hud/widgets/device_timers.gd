## PO6-03: PD2-style device timer panel over every running device (drill / thermal drill / saw / hack / time lock /
## C4), projected at the device through the local camera: the device name, time left (mm:ss) and a progress bar; while
## jammed the panel turns red with "JAMMED" (hack: "INTERRUPTED") and the fix prompt with the interact key. Panels
## shrink with distance, hide past HudTweak.device_panel_max_m, behind the camera or behind a wall (a throttled ray on
## HudTweak.device_occlusion_mask). Owner: ENV B.
## Data: the model's `devices` rows when it has them ([{net_id, kind, world_pos, progress, time_left_s, state,
## fix_prompt_key}], asked of ENV A for ui_hud.md), else rows built here from EventBus device_started / jammed /
## restarted / finished [R] (progress extrapolated from the started duration; the device position from Ids.lookup).
## `objective_line(objective)` gives the HUD objective line its "02:31" / "JAMMED" suffix for the device that serves
## the current objective (`device_net_id` on the objective row, else the nearest row of a matching kind).
class_name DeviceTimers
extends HudWidget

## Emitted when the current objective's device suffix changes (text "" = none).
signal objective_suffix_changed(text: String, jammed: bool)

const STATE_RUNNING: StringName = &"running"
const STATE_JAMMED: StringName = &"jammed"
## Model rows only (power cut / lockdown on a hack): amber PAUSED, no fix prompt.
const STATE_PAUSED: StringName = &"paused"
## Device kind -> name key.
const KIND_KEYS: Dictionary = {
	&"drill": &"ui.hud.device.drill", &"thermal": &"ui.hud.device.thermal", &"saw": &"ui.hud.device.saw",
	&"hack": &"ui.hud.device.hack", &"time_lock": &"ui.hud.device.time_lock", &"c4": &"ui.hud.device.c4",
	&"thermite": &"ui.hud.device.thermite",  # D-115: Dockside Burn's burn_point (device_started kind)
}
## LEAD r245 (OF HUD pass): a step the mission times without a device (objective data `seconds`: the OF / ND time
## lock, DB's escape ETA) counts down on the objective line too. Objective id prefix -> name key; else WAIT.
const WAIT_KEYS: Dictionary = {"time_lock": &"ui.hud.device.time_lock", "escape": &"ui.hud.device.escape"}
const WAIT_DEFAULT: StringName = &"ui.hud.device.wait"
## Device kind -> fix prompt when the row has none (the device's own interactable prompt).
const FIX_KEYS: Dictionary = {&"hack": &"ui.prompt.restart_hack"}
const FIX_DEFAULT: StringName = &"ui.prompt.fix_drill"
## Objective glyph kinds (ObjectiveMarkers.kind_for) a device kind can serve.
const SERVES: Dictionary = {
	&"drill": [&"drill", &"safe", &"door"], &"thermal": [&"drill", &"safe", &"door"], &"saw": [&"drill", &"safe", &"door"],
	&"hack": [&"laptop", &"drill"], &"time_lock": [&"drill", &"safe", &"laptop"], &"c4": [&"safe", &"door"],
	&"thermite": [&"fire"],
}
const PANEL_W: float = 168.0
const PANEL_H: float = 62.0

## Last drawn panels: [{net_id, kind, pos: Vector2 (local, panel centre), scale, jammed, time_text, label}] (tests).
## ui_hud v1.16 scoped ADS: the scope ring in this widget's local space (Hud sets it); panels inside it are not drawn.
var avoid: Rect2 = Rect2()
## r228 windowed check: a panel under this rect (the toast's text, HUD units) steps down below it.
var yield_rect: Rect2 = Rect2()
var drawn: Array[Dictionary] = []
## Rows built from EventBus while the model has no `devices`: net_id -> {kind, duration, progress, state}.
var tracked: Dictionary = {}
var _font: Font
var _occluded: Dictionary = {}  # net_id -> bool, refreshed every device_occlusion_check_s
var _occlusion_t: float = 0.0
var _suffix: String = ""
var _suffix_jammed: bool = false
## The current step's device-less wait: {"id", "seconds", "elapsed"} (game time; empty = none).
var _wait: Dictionary = {}


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = UiTokens.font_caps()


func _enter_tree() -> void:
	EventBus.device_started.connect(_on_started)
	EventBus.device_jammed.connect(_on_jammed)
	EventBus.device_restarted.connect(_on_restarted)
	EventBus.device_finished.connect(_on_finished)


func _exit_tree() -> void:
	EventBus.device_started.disconnect(_on_started)
	EventBus.device_jammed.disconnect(_on_jammed)
	EventBus.device_restarted.disconnect(_on_restarted)
	EventBus.device_finished.disconnect(_on_finished)
	tracked.clear()


func watched_signals() -> Array[StringName]:
	return [&"devices_changed", &"objectives_changed"]


func refresh() -> void:
	var live: bool = not rows().is_empty()
	if not live:
		drawn.clear()
	_update_suffix()
	set_process(live or _suffix != "")
	queue_redraw()


## Every placed device: the model's rows when it publishes them, else the EventBus-tracked ones.
func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var live: Variant = prop(&"devices", null)
	if live is Array:
		for r: Variant in live as Array:
			if r is Dictionary:
				out.append(r as Dictionary)
		return out
	for id: Variant in tracked:
		var t: Dictionary = tracked[id]
		var dur: float = float(t["duration"])
		var p: float = clampf(float(t["progress"]), 0.0, 1.0)
		out.append({"net_id": int(id), "kind": t["kind"], "progress": p, "time_left_s": maxf(dur * (1.0 - p), 0.0),
				"state": t["state"], "world_pos": _world_pos(int(id))})
	return out


## "02:31" (minutes:seconds, rounded up so it reads 00:01 until it is done).
static func time_text(seconds: float) -> String:
	var s: int = ceili(maxf(seconds, 0.0))
	return UiText.t(&"ui.hud.device.time", {"mm": "%02d" % (s / 60), "ss": "%02d" % (s % 60)})


static func is_jammed(row: Dictionary) -> bool:
	return StringName(row.get("state", STATE_RUNNING)) == STATE_JAMMED


static func kind_name(kind: StringName) -> String:
	return UiText.t(KIND_KEYS.get(kind, &"ui.hud.device.drill") as StringName)


static func is_paused(row: Dictionary) -> bool:
	return StringName(row.get("state", STATE_RUNNING)) == STATE_PAUSED


static func jam_text(kind: StringName) -> String:
	return UiText.t(&"ui.hud.device.interrupted" if kind == &"hack" else &"ui.hud.device.jammed")


## r227 crowding audit: true while the interaction prompt already shows this row's fix prompt (the player is at the
## device): the panel's own fix line would repeat it right over the prompt.
func _prompt_shows_fix(row: Dictionary) -> bool:
	var it: Dictionary = prop(&"interaction", {}) as Dictionary
	var kind: StringName = StringName(row.get("kind", &"drill"))
	var key: StringName = StringName(row.get("fix_prompt_key", &""))
	if key == &"":
		key = FIX_KEYS.get(kind, FIX_DEFAULT) as StringName
	return not it.is_empty() and StringName(it.get("text_key", &"")) == key


## The fix prompt of a jammed row ("Hold F to fix the drill").
static func fix_text(row: Dictionary) -> String:
	var kind: StringName = StringName(row.get("kind", &"drill"))
	var key: StringName = StringName(row.get("fix_prompt_key", &""))
	if key == &"":
		key = FIX_KEYS.get(kind, FIX_DEFAULT) as StringName
	return UiText.t(key, {"key": InteractionPanel.action_key_text(InteractionPanel.INTERACT_ACTION)})


## The device row serving objective `o`: its `device_net_id` when set, else the nearest row whose kind can serve the
## objective's glyph kind (ObjectiveMarkers.kind_for), measured from the objective's marker; {} = none.
func device_for_objective(o: Dictionary) -> Dictionary:
	var all: Array[Dictionary] = rows()
	if all.is_empty() or o.is_empty():
		return {}
	var want: int = int(o.get("device_net_id", -1))
	if want >= 0:
		for r: Dictionary in all:
			if int(r.get("net_id", -1)) == want:
				return r
		return {}
	var glyph: StringName = ObjectiveMarkers.kind_for(o)
	var at: Variant = null
	for m: Dictionary in prop(&"objective_markers", []) as Array:
		if StringName(m.get("id", &"")) == StringName(o.get("id", &"")):
			at = m.get("position", null)
	var best: Dictionary = {}
	var best_d: float = INF
	for r: Dictionary in all:
		if not (SERVES.get(StringName(r.get("kind", &"")), []) as Array).has(glyph):
			continue
		var d: float = 0.0
		if at is Vector3 and r.get("world_pos", null) is Vector3:
			d = (at as Vector3).distance_to(r["world_pos"] as Vector3)
		if d < best_d:
			best_d = d
			best = r
	return best


## Objective-line suffix for objective `o` ("DRILL 02:31" / "DRILL JAMMED"); "" when no device serves it.
func objective_line(o: Dictionary) -> String:
	var r: Dictionary = device_for_objective(o)
	if r.is_empty():
		return _wait_line(o)
	var kind: StringName = StringName(r.get("kind", &"drill"))
	var tail: String = jam_text(kind) if is_jammed(r) else time_text(float(r.get("time_left_s", 0.0)))
	if is_paused(r):
		tail = UiText.t(&"ui.hud.device.paused")
	return UiText.t(&"ui.hud.device.objective_suffix", {"device": kind_name(kind), "time": tail})


## "TIME LOCK 03:12" for a step whose data has `seconds` and no device serves it, counted from when it became the
## current step (restarts when the mission changes `seconds`); "" otherwise.
func _wait_line(o: Dictionary) -> String:
	var secs: Variant = (o.get("args", {}) as Dictionary).get("seconds")
	if not (secs is float or secs is int) or float(secs) <= 0.0:
		_wait = {}
		return ""
	var id: String = String(o.get("id", &""))
	if String(_wait.get("id", "")) != id or not is_equal_approx(float(_wait.get("seconds", -1.0)), float(secs)):
		_wait = {"id": id, "seconds": float(secs), "elapsed": 0.0}
	var key: StringName = WAIT_DEFAULT
	for prefix: String in WAIT_KEYS:
		if id.begins_with(prefix):
			key = WAIT_KEYS[prefix]
	var left: float = float(_wait["seconds"]) - float(_wait["elapsed"])
	return UiText.t(&"ui.hud.device.objective_suffix", {"device": UiText.t(key), "time": time_text(left)})


func _process(delta: float) -> void:
	if not _wait.is_empty():
		_wait["elapsed"] = float(_wait["elapsed"]) + delta
	for id: Variant in tracked:
		var t: Dictionary = tracked[id]
		if StringName(t["state"]) == STATE_RUNNING and float(t["duration"]) > 0.0:
			t["progress"] = minf(float(t["progress"]) + delta / float(t["duration"]), 1.0)
	_occlusion_t -= delta
	var all: Array[Dictionary] = rows()
	if _occlusion_t <= 0.0:
		_occlusion_t = tweak.device_occlusion_check_s
		_check_occlusion(all)
	_layout(all)
	_update_suffix()
	queue_redraw()
	if all.is_empty() and _suffix == "":
		set_process(false)


func _update_suffix() -> void:
	var cur: Dictionary = {}
	for o: Dictionary in prop(&"objectives", []) as Array:
		if int(o.get("state", Enums.ObjectiveState.ACTIVE)) == Enums.ObjectiveState.ACTIVE \
				and not bool((o.get("args", {}) as Dictionary).get("disabled", false)):
			cur = o
			break
	var text: String = objective_line(cur)
	var r: Dictionary = device_for_objective(cur) if text != "" else {}
	var jammed: bool = not r.is_empty() and is_jammed(r)
	if text != _suffix or jammed != _suffix_jammed:
		_suffix = text
		_suffix_jammed = jammed
		objective_suffix_changed.emit(text, jammed)


func _layout(all: Array[Dictionary]) -> void:
	drawn.clear()
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
	for r: Dictionary in all:
		var wp: Variant = r.get("world_pos", null)
		if not wp is Vector3:
			continue
		var world: Vector3 = wp as Vector3
		var dist: float = cam.global_position.distance_to(world)
		var id: int = int(r.get("net_id", -1))
		if dist > tweak.device_panel_max_m or cam.is_position_behind(world) or bool(_occluded.get(id, false)):
			continue
		var kind: StringName = StringName(r.get("kind", &"drill"))
		var jammed: bool = is_jammed(r)
		var fix: String = fix_text(r) if jammed and not _prompt_shows_fix(r) else ""
		var restart: float = float(r.get("auto_restart_in_s", -1.0))
		if jammed and restart >= 0.0:
			fix = UiText.t(&"ui.hud.device.restarting", {"time": time_text(restart)})
		drawn.append({"paused": is_paused(r),"net_id": id, "kind": kind, "pos": to_local * cam.unproject_position(world),
				"scale": clampf(tweak.device_panel_ref_m / maxf(dist, 0.01), tweak.device_panel_min_scale, 1.0),
				"jammed": jammed, "progress": clampf(float(r.get("progress", 0.0)), 0.0, 1.0),
				"time_text": time_text(float(r.get("time_left_s", 0.0))), "label": kind_name(kind),
				"jam_text": jam_text(kind) if jammed else "", "fix_text": fix})


## Hide panels a wall stands in front of (camera -> device ray on device_occlusion_mask; hits within
## device_occlusion_slack_m of the device are the device itself).
func _check_occlusion(all: Array[Dictionary]) -> void:
	_occluded.clear()
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or tweak.device_occlusion_mask == 0:
		return
	var space: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
	for r: Dictionary in all:
		var wp: Variant = r.get("world_pos", null)
		if not wp is Vector3:
			continue
		var to: Vector3 = wp as Vector3
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cam.global_position, to,
				tweak.device_occlusion_mask)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(to) > tweak.device_occlusion_slack_m:
			_occluded[int(r.get("net_id", -1))] = true


func _draw() -> void:
	for d: Dictionary in drawn:
		d["hidden_by_scope"] = false
		d["yielded"] = false
		var s: float = float(d["scale"])
		var c: Vector2 = d["pos"] as Vector2
		var jammed: bool = bool(d["jammed"])
		var paused: bool = bool(d.get("paused", false))
		var accent: Color = tweak.device_jam_color if jammed else (UiTokens.WARN if paused else tweak.objective_color)
		var fs: int = maxi(roundi(UiTokens.FONT_SMALL * s), 11)
		var big: int = maxi(roundi(UiTokens.FONT_LEAD * s), 13)
		var pad: float = 8.0 * s
		var main: String = String(d["jam_text"]) if jammed else String(d["time_text"])
		if paused:
			main = UiText.t(&"ui.hud.device.paused")
		# PO6-03 GH capture: "DRILL" ran into "JAMMED" in a fixed-width panel; it grows to fit name + gap + main text.
		var need: float = _font.get_string_size(String(d["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x \
				+ _font.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x + 4.0 * pad
		var w: float = maxf(PANEL_W * s, need)
		d["width"] = w
		var h: float = PANEL_H * s
		var r: Rect2 = Rect2(c - Vector2(w * 0.5, h), Vector2(w, h))
		if avoid.has_area() and avoid.intersects(r):
			d["hidden_by_scope"] = true  # ui_hud v1.16: no text panel inside the scope ring (PD2)
			continue
		if yield_rect.has_area() and yield_rect.intersects(r):
			r.position.y = yield_rect.end.y + pad  # "Alarm raised" sat on DRILL JAMMED (r228)
			d["yielded"] = true
			c.y = r.end.y
		draw_rect(r, Color(UiTokens.INK_0, UiTokens.HUD_PANEL_ALPHA + 0.15))
		draw_rect(r, accent, false, maxf(2.0 * s, 1.0))
		_text(Vector2(r.position.x + pad, r.position.y + pad + fs), String(d["label"]), fs, UiTokens.PAPER_DIM, false)
		_text(Vector2(r.end.x - pad, r.position.y + pad + big * 0.9), main, big,
				accent if jammed or paused else UiTokens.PAPER, true)
		var bar: Rect2 = Rect2(r.position.x + pad, r.end.y - pad - 6.0 * s, w - 2.0 * pad, maxf(6.0 * s, 3.0))
		draw_rect(bar, Color(UiTokens.LINE, 0.9))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(d["progress"]), bar.size.y)), accent)
		if jammed and String(d["fix_text"]) != "":
			_text(Vector2(c.x, r.end.y + fs + 4.0 * s), String(d["fix_text"]), fs, UiTokens.CYAN, false, true)


func _text(at: Vector2, s: String, fs: int, col: Color, right: bool, center: bool = false) -> void:
	var w: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p: Vector2 = at - Vector2(w, 0) if right else (at - Vector2(w * 0.5, 0) if center else at)
	draw_string_outline(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 1))
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _on_started(device_net_id: int, kind: StringName, duration: float) -> void:
	tracked[device_net_id] = {"kind": kind, "duration": maxf(duration, 0.0), "progress": 0.0, "state": STATE_RUNNING}
	refresh()


func _on_jammed(device_net_id: int) -> void:
	if tracked.has(device_net_id):
		(tracked[device_net_id] as Dictionary)["state"] = STATE_JAMMED
	refresh()


func _on_restarted(device_net_id: int, _crew_slot: int) -> void:
	if tracked.has(device_net_id):
		(tracked[device_net_id] as Dictionary)["state"] = STATE_RUNNING
	refresh()


func _on_finished(device_net_id: int) -> void:
	tracked.erase(device_net_id)
	refresh()


## Where a tracked device's panel floats: the device node's origin, HudTweak.device_panel_up_m up and
## device_panel_out_m out of the surface it works on (+Z: DrillPoint's -Z points into the lock).
func _world_pos(net_id: int) -> Variant:
	var n: Node3D = Ids.lookup(net_id) as Node3D
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return null
	return n.global_position + Vector3.UP * tweak.device_panel_up_m + n.global_basis.z.normalized() * tweak.device_panel_out_m
