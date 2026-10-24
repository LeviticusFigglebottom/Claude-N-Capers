## D-165 windowed dress review of ENV D's Afterhours props (prop_ah_*) where C's ah_dress placed them, under the real
## ClubLights. Launches the heist, shoots every prop_ah_* instance in place in stealth (state &"club"), raises the alarm
## (the mission puts ClubLights to &"house") and shoots one instance of every prop id again from the same view. Each
## view: the prop's mesh bounds centre from its front (Godot -Z), the clearest of 8 directions around it (ray test,
## the prop's own colliders excluded), at a distance set by its size; props high up (truss, mirror ball) are shot from
## standing eye height below. Composes a contact sheet per light state and logs every instance with its position, size
## and nearest light. PNGs, sheets and log go to --out.
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 60 \
##     --resolution 960x540 \
##     --path game res://world/characters/_tools/render_ah_dress_review.tscn -- --out=/abs/dir [--seed=1] [--only=id,id]
## Owner: ENV D.
extends Node3D

const COLS: int = 4
const THUMB: Vector2i = Vector2i(480, 270)
const PREFIX: String = "prop_ah_"
const EYE_H: float = 1.65
## props whose bounds centre is higher than this are shot from below (standing eye height)
const HIGH_Y: float = 3.0
const MIN_DIST: float = 1.4

var _out: String = ""
var _seed: int = 1
## --only=a,b: only these prop ids (without the prefix too, e.g. back_bar,marquee)
var _only: PackedStringArray = []
var _cam: Camera3D = null
var _label: Label = null
var _log: PackedStringArray = []
var _shots: Dictionary = {"club": [], "house": []}
## prop node -> [eye, target], from the club pass, reused for the house pass
var _views: Dictionary = {}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--seed="):
			_seed = int(a.trim_prefix("--seed="))
		elif a.begins_with("--only="):
			for s: String in a.trim_prefix("--only=").split(",", false):
				_only.append(s if s.begins_with(PREFIX) else PREFIX + s)
	if _out == "":
		_out = OS.get_user_data_dir() + "/ah_dress"
	RenderingServer.render_loop_enabled = false  # frames only for the shots (llvmpipe draws this map slowly)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var opts: Dictionary = {"crew_ai": false, "ai_teammates": 0, "probe_prewarm": false}
	var rt: HeistRuntime = await HeistLauncher.launch(&"afterhours", _seed, Enums.Difficulty.ROUTINE, self, opts)
	if rt == null:
		push_error("[AHDRESS] launch failed")
		get_tree().quit(1)
		return
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.fov = 60.0
	_cam.current = true
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(8, 6)
	_label.add_theme_font_size_override(&"font_size", 20)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)
	await _ticks(90)
	var map: Node = rt.get_parent() if rt.get_parent() != null else get_tree().root
	var props: Array[Node3D] = _find_props(map)
	_say("seed %d lights %s props %d" % [_seed, _lights_state(), props.size()])
	var first: Dictionary = {}
	for p: Node3D in props:
		var id: String = _prop_id(p)
		var bb: AABB = _bounds(p)
		_say("%s %s at (%.2f, %.2f, %.2f) yaw %.0f size (%.2f, %.2f, %.2f)" % [p.name, id, p.global_position.x,
			p.global_position.y, p.global_position.z, rad_to_deg(p.global_rotation.y), bb.size.x, bb.size.y, bb.size.z])
		_views[p] = _view(p, bb)
		if not first.has(id):
			first[id] = p
		await _prop_shot("club", p)
	if rt.mission != null:
		rt.mission.raise_alarm(&"dress_review")
		await _ticks(20)
		_say("alarm raised, lights %s" % _lights_state())
		for id: String in first:
			await _prop_shot("house", first[id])
	for phase: String in _shots:
		_sheet(phase)
	_finish()


## Every node instanced from a prop_ah_* scene (the wrapper, not the glb inside it), in tree order.
func _find_props(map: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in map.find_children("*", "Node3D", true, false):
		var id: String = _prop_id(n)
		if id == "" or (not _only.is_empty() and not _only.has(id)):
			continue
		# skip the glb instanced inside a wrapper already taken
		var nested: bool = false
		for q: Node3D in out:
			if q.is_ancestor_of(n):
				nested = true
				break
		if not nested:
			out.append(n as Node3D)
	return out


func _prop_id(n: Node) -> String:
	var f: String = n.scene_file_path.get_file().get_basename()
	return f if f.begins_with(PREFIX) else ""


func _bounds(p: Node3D) -> AABB:
	var bb: AABB = AABB()
	var any: bool = false
	for n: Node in p.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = n as VisualInstance3D
		if not vi.is_visible_in_tree() or vi is Light3D:
			continue
		var w: AABB = vi.global_transform * vi.get_aabb()
		bb = w if not any else bb.merge(w)
		any = true
	return bb if any else AABB(p.global_position, Vector3.ONE * 0.2)


## [eye, target]: from the prop's front, the clearest of 8 directions.
func _view(p: Node3D, bb: AABB) -> Array:
	var at: Vector3 = bb.get_center()
	var excl: Array[RID] = []
	for n: Node in p.find_children("*", "CollisionObject3D", true, false):
		excl.append((n as CollisionObject3D).get_rid())
	if p is CollisionObject3D:
		excl.append((p as CollisionObject3D).get_rid())
	var floor_y: float = _floor_under(bb.position + Vector3(bb.size.x * 0.5, 0.0, bb.size.z * 0.5), excl)
	var high: bool = at.y - floor_y > HIGH_Y
	# the prop front is its local -Z (Blender +Y)
	var fwd: Vector3 = -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var reach: float = maxf(Vector2(bb.size.x, bb.size.z).length(), bb.size.y)
	var dist: float = maxf(MIN_DIST, reach * 1.1 + 0.5)
	var eye_y: float = floor_y + EYE_H if high else clampf(at.y + 0.35, floor_y + 1.0, floor_y + 2.4)
	var base: Vector3 = fwd * dist + Vector3(fwd.z, 0.0, -fwd.x) * dist * 0.35
	var from: Vector3 = Vector3(at.x, eye_y, at.z)
	var best: float = -1.0
	var eye: Vector3 = from + base
	for k: int in 8:
		var cand: Vector3 = from + base.rotated(Vector3.UP, k * PI / 4.0)
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, cand)
		q.exclude = excl
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		var d: float = from.distance_to(cand) if hit.is_empty() else maxf(from.distance_to(hit["position"]) - 0.2, 0.8)
		if d > best + 0.3:
			best = d
			eye = from + (cand - from).normalized() * d
	return [eye, at]


## The walkable surface under the prop's bounds bottom (its own colliders excluded).
func _floor_under(at: Vector3, excl: Array[RID]) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.1, at + Vector3.DOWN * 30.0)
	q.exclude = excl
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else 0.0


func _prop_shot(phase: String, p: Node3D) -> void:
	var name: String = "%s_%02d_%s" % [phase, (_shots[phase] as Array).size() + 1, _prop_id(p).trim_prefix(PREFIX)]
	_label.text = "%s  %s (%s)\nlights %s" % [name, _prop_id(p), p.name, _lights_state()]
	await _shot(phase, name, _views[p][0], _views[p][1])


func _lights_state() -> String:
	var cl: Node = get_tree().root.find_child("ClubLights", true, false)
	return str(cl.get("state")) if cl != null else "-"


func _sheet(phase: String) -> void:
	var shots: Array = _shots[phase]
	if shots.is_empty():
		return
	var rows: int = ceili(float(shots.size()) / COLS)
	var sheet: Image = Image.create(THUMB.x * COLS, THUMB.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for k: int in shots.size():
		var img: Image = Image.load_from_file("%s/%s.png" % [_out, shots[k]])
		if img == null:
			continue
		img.convert(Image.FORMAT_RGB8)
		img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, THUMB), Vector2i((k % COLS) * THUMB.x, (k / COLS) * THUMB.y))
	sheet.save_png("%s/ah_dress_%s_sheet.png" % [_out, phase])
	_say("sheet ah_dress_%s_sheet.png %d shots" % [phase, shots.size()])


func _finish() -> void:
	var f: FileAccess = FileAccess.open("%s/ah_dress_log.txt" % _out, FileAccess.WRITE)
	if f == null:
		push_error("[AHDRESS] could not write the log (%s)" % error_string(FileAccess.get_open_error()))
	else:
		f.store_string("\n".join(_log) + "\n")
		f.close()
	print("[AHDRESS] RESULT DONE %s" % _out)
	get_tree().quit(0)


func _shot(phase: String, name: String, eye: Vector3, at: Vector3) -> void:
	if eye.distance_to(at) < 0.05:
		eye += Vector3(0.0, 0.5, 1.0)
	_cam.look_at_from_position(eye, at)
	for n: Node in get_tree().root.find_children("*", "", true, false):
		if n is FpViewmodel:
			(n as Node3D).visible = false  # the player's first-person gun would draw over the review camera
	RenderingServer.render_loop_enabled = true
	for _i: int in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = false
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [_out, name])
	(_shots[phase] as Array).append(name)


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func _say(s: String) -> void:
	_log.append(s)
	print("[AHDRESS] " + s)
