## D-116 follow-up (organic, third person): how teammates and bots hold their weapons, windowed, in a lit heist.
## Two crew rigs stand in front of the heist's first Spawns marker, a rifle and a pistol, each WeaponVisual attached
## at HandR/Socket exactly as AnimDriver.refresh_weapon does, posed at idle_alert, walk (mid stride), aim. A 3/4
## front view plus a close-up of the hands per pose.
## Writes <out>/<pose>.png, <out>/<pose>_close.png and <out>/crew_hold_sheet.png (rows = poses).
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 960x540 --path game res://world/characters/_tools/render_crew_hold_review.tscn -- --out=/abs/dir \
##     [--heist=glasshouse]
## Owner: ENV D.
extends Node

## [character scene id, weapon id, weapon kind]
const BOTS: Array = [["crew_rook", &"weapon.corsair_ar", &"rifle"], ["crew_sable", &"weapon.kestrel_p9", &"pistol"]]
const ANIM_LIB: String = "humanoid/"

var _out: String = "user://crew_hold_review"
var _heist: String = "glasshouse"
## pose name -> [clip for rifle, clip for pistol, time (s)]
var _poses: Array = [["idle_alert", "idle_alert", "idle_alert", 0.5], ["walk", "walk", "walk", 0.3],
	["aim", "aim_rifle", "aim_pistol", 0.5]]


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": _out = v
			"heist": _heist = v
	DirAccess.make_dir_recursive_absolute(_out)
	RenderingServer.render_loop_enabled = false   # llvmpipe: render only the saved frames (a lit heist is slow)
	var level: Node3D = (load("res://world/heists/%s/%s.tscn" % [_heist, _heist]) as PackedScene).instantiate() as Node3D
	add_child(level)
	for _i: int in 3:
		await get_tree().physics_frame
	var spawn: Node3D = _first_spawn(level)
	var o: Vector3 = spawn.global_position if spawn != null else Vector3.ZERO
	var fwd: Vector3 = (-spawn.global_basis.z if spawn != null else Vector3.FORWARD)
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side: Vector3 = fwd.cross(Vector3.UP).normalized()
	var rigs: Array[Node3D] = []
	for i: int in BOTS.size():
		var spec: Array = BOTS[i]
		var rig: Node3D = (load("res://world/characters/%s/%s.tscn" % [spec[0], spec[0]]) as PackedScene).instantiate()
		add_child(rig)
		var p: Vector3 = o + fwd * 3.0 + side * (0.55 if i == 0 else -0.55)
		rig.global_position = p
		rig.look_at(o + side * (0.3 if i == 0 else -0.3), Vector3.UP, true)   # facing the camera, turned 3/4
		rig.rotate_y(deg_to_rad(28.0 if i == 0 else -28.0))
		_attach(rig, StringName(spec[1]))
		rigs.append(rig)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	var mid: Vector3 = o + fwd * 3.0
	var rows: Array[Array] = []
	for pose: Array in _poses:
		for i: int in rigs.size():
			var clip: String = String(pose[1] if BOTS[i][2] == &"rifle" else pose[2])
			_pose(rigs[i], clip, float(pose[3]))
		await get_tree().process_frame
		cam.global_position = o + Vector3.UP * 1.55 + fwd * 0.4
		cam.look_at(mid + Vector3.UP * 1.1)
		cam.current = true
		var full: Image = await _shot()
		full.save_png("%s/%s.png" % [_out, pose[0]])
		cam.global_position = mid + Vector3.UP * 1.25 - fwd * 1.45
		cam.look_at(mid + Vector3.UP * 1.12)
		var close: Image = await _shot()
		close.save_png("%s/%s_close.png" % [_out, pose[0]])
		rows.append([full, close])
	_sheet(rows)
	RenderingServer.render_loop_enabled = true
	print("[CREWHOLD] RESULT DONE %s/crew_hold_sheet.png" % _out)
	get_tree().quit(0)


func _first_spawn(level: Node) -> Node3D:
	var spawns: Node = level.get_node_or_null(^"Spawns")
	if spawns == null:
		return null
	for c: Node in spawns.get_children():
		if c is Node3D:
			return c as Node3D
	return null


## AnimDriver.refresh_weapon: the WeaponDef's WeaponVisual (no mods) at HandR/Socket.
func _attach(rig: Node3D, wid: StringName) -> void:
	var def: WeaponDef = ContentDB.weapon(wid)
	var socket: Node3D = rig.get_node_or_null(^"Skeleton3D/HandR/Socket") as Node3D
	if def == null or def.model == null or socket == null:
		push_warning("crew hold review: no weapon / socket for %s" % wid)
		return
	var wv: WeaponVisual = WeaponVisual.new()
	socket.add_child(wv)
	wv.setup(def, [] as Array[StringName])


func _pose(rig: Node3D, clip: String, t: float) -> void:
	var ap: AnimationPlayer = rig.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if ap == null or not ap.has_animation(ANIM_LIB + clip):
		push_warning("crew hold review: no clip %s" % clip)
		return
	ap.play(ANIM_LIB + clip)
	ap.seek(t, true)
	ap.pause()


func _shot() -> Image:
	RenderingServer.render_loop_enabled = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	return img


func _sheet(rows: Array[Array]) -> void:
	var w: int = (rows[0][0] as Image).get_width() / 2
	var h: int = (rows[0][0] as Image).get_height() / 2
	var sheet: Image = Image.create(w * 2, h * rows.size(), false, Image.FORMAT_RGB8)
	for r: int in rows.size():
		for c: int in 2:
			var img: Image = (rows[r][c] as Image).duplicate() as Image
			img.convert(Image.FORMAT_RGB8)
			img.resize(w, h)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(c * w, r * h))
	sheet.save_png("%s/crew_hold_sheet.png" % _out)
