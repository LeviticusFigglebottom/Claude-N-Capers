## Rolling Thunder G2 haze review (the LEAD's 2026-10-22 lighting review: the dust haze washed the exteriors and reached
## the interiors). Launches the heist and renders, from the live map with its environment: the junction and the
## attendant booth review cameras, an exterior pedestrian from 3 m and 10 m, and a diner customer from 3 m. PNGs to
## --out. Use the compatibility renderer the low-end players see:
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 1280x720 --path game res://world/tools/rt_haze_review.tscn -- --out=/abs/dir [--shots=a,b]
## Owner: ENV C.
extends Node3D

const EYE_H: float = 1.6
## The diner's dining room (the interior subject); the exterior subject is the pedestrian nearest the junction on
## Orchard or Tannery.
const DINER: AABB = AABB(Vector3(14.0, -0.5, 14.0), Vector3(13.0, 3.0, 12.0))
const CAMERAS: Array[String] = ["rc_ext_junction", "rc_carpark_booth", "rc_diner_dining"]

var _out: String = ""
var _only: PackedStringArray = PackedStringArray()   # --shots: render only these (default: all)
var _cam: Camera3D = null
var _rt: HeistRuntime = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--shots="):
			_only = a.trim_prefix("--shots=").split(",", false)
	if _out == "":
		_out = OS.get_user_data_dir() + "/rt_haze"
	RenderingServer.render_loop_enabled = false
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	_rt = await HeistLauncher.launch(&"rolling_thunder", 1, Enums.Difficulty.ROUTINE, self,
		{"crew_ai": false, "ai_teammates": 0})
	if _rt == null:
		push_error("[RTHAZE] launch failed")
		get_tree().quit(1)
		return
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	for _i: int in 60:
		await get_tree().physics_frame
	for nm: String in CAMERAS:
		var m: Node3D = _rt.map.find_child(nm, true, false) as Node3D
		if m == null:
			continue
		_cam.fov = float(m.get_meta(&"fov", 70.0))
		_cam.global_transform = m.global_transform
		await _snap(nm)
	var street: NpcBase = null
	var diner: NpcBase = null
	for n: Node in _rt.npcs():
		var npc: NpcBase = n as NpcBase
		if npc == null or not npc.visible:
			continue
		var p: Vector3 = npc.global_position
		if diner == null and DINER.has_point(p + Vector3.UP * 0.5):
			diner = npc
		elif absf(p.y) < 0.5 and (absf(p.x) < 13.0 or absf(p.z) < 11.0):   # on Orchard or Tannery
			if street == null or Vector2(p.x, p.z).length() < Vector2(street.global_position.x,
					street.global_position.z).length():
				street = npc
	if street != null:
		await _subject("street_3m", street, 3.0)
		await _subject("street_10m", street, 10.0)
	if diner != null:
		await _subject("diner_3m", diner, 3.0)
	print("[RTHAZE] RESULT DONE %s" % _out)
	get_tree().quit(0)


## `npc` from `dist` m in front (the clearest of 8 directions around its facing).
func _subject(nm: String, npc: NpcBase, dist: float) -> void:
	var at: Vector3 = npc.global_position + Vector3.UP * 1.1
	var fwd: Vector3 = -npc.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var best: float = -1.0
	var eye: Vector3 = at + fwd * dist
	for k: int in 8:
		var cand: Vector3 = at + (fwd * dist).rotated(Vector3.UP, k * PI / 4.0) + Vector3.UP * (EYE_H - 1.1)
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at, cand)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		var d: float = at.distance_to(cand) if hit.is_empty() else at.distance_to(hit["position"]) - 0.2
		if d > best + 0.3:
			best = d
			eye = at + (cand - at).normalized() * d
	_cam.fov = 50.0
	_cam.look_at_from_position(eye, at)
	print("[RTHAZE] %s %s at %s, eye %.1f m" % [nm, npc.name, npc.global_position, eye.distance_to(at)])
	await _snap(nm)


func _snap(nm: String) -> void:
	if not _only.is_empty() and not _only.has(nm):
		return
	RenderingServer.render_loop_enabled = true
	for _i: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = false
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [_out, nm])
