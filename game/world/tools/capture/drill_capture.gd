## Windowed close-up of a placed drill device at its DrillPoint, from the side (PO: the lance must touch the door).
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --rendering-driver opengl3 --path game \
##     res://world/tools/capture/drill_capture.tscn -- --heist=dockside_burn \
##     --point=Gameplay/Doors/StrongroomDoor/StrongroomDrill --out=/abs/path.png [--side=1.3] [--frames=3]
## Owner: ENV C.
extends Node

var _heist: StringName = &"dockside_burn"
var _point: String = ""
var _out: String = "user://drill.png"
var _side: float = 1.3
var _frames: int = 3


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--heist="):
			_heist = StringName(a.trim_prefix("--heist="))
		elif a.begins_with("--point="):
			_point = a.trim_prefix("--point=")
		elif a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--side="):
			_side = float(a.trim_prefix("--side="))
		elif a.begins_with("--frames="):
			_frames = int(a.trim_prefix("--frames="))
	var rt: HeistRuntime = await HeistLauncher.launch(_heist, 1002, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false})
	var dp: DrillPoint = rt.map.get_node_or_null(NodePath(_point)) as DrillPoint if rt != null else null
	if dp == null:
		push_error("drill_capture: no DrillPoint %s" % _point)
		get_tree().quit(1)
		return
	dp.runner.place(0, 999.0)  # long run: the device stays placed for the shot
	dp.runner.jams.clear()
	await get_tree().process_frame
	# Stand in for A's DrillPoint state toggle (Device/Sparks.emitting, Device/Glow.visible while RUNNING).
	var dev: Node = dp.get_node_or_null(^"Device")
	if dev != null:
		var sp: Node = dev.get_node_or_null(^"Sparks")
		if sp != null:
			sp.set(&"emitting", true)
		var gl: Node3D = dev.get_node_or_null(^"Glow") as Node3D
		if gl != null:
			gl.visible = true
	var xf: Transform3D = dp.global_transform
	var tip: Vector3 = xf.origin
	var cam: Camera3D = Camera3D.new()
	cam.fov = 50.0
	rt.map.add_child(cam)
	# Side view: off the point's local +X, a little above, looking at the contact point.
	cam.global_position = tip + xf.basis.x.normalized() * _side + Vector3.UP * 0.25 + xf.basis.z.normalized() * 0.35
	cam.look_at(tip + xf.basis.z.normalized() * 0.25, Vector3.UP)
	cam.make_current()
	for _i: int in maxi(_frames, 12):  # let the sparks fill in
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out)
	print("drill_capture: saved %s" % _out)
	get_tree().quit(0)
