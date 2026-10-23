## PO report (OF drill) windowed evidence (D-086): Ostrander Federal's LidDrill (the thermal drill spot over the vault
## lid, teller workroom) before placement (only the spot's mark) and placed (the thermal device, its bit along the
## spot's -Z). PNGs go to --cap-out. Owner: ENV A.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 1280x720 \
##     res://tests/a/e2e/of_drill_capture.tscn -- --cap-out=/abs/dir
extends Node3D

var _out: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--cap-out="):
			_out = a.trim_prefix("--cap-out=")
	if _out == "":
		_out = OS.get_user_data_dir() + "/of_drill"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"ostrander_federal", 3, Enums.Difficulty.ROUTINE, self,
		{"crew_ai": false, "skip_casing": true})
	if rt == null:
		push_error("[OFDRILL] launch failed")
		get_tree().quit(1)
		return
	print("[OFDRILL] launched")
	rt.isolate_npc(null)
	var dp: DrillPoint = rt.map.get_node_or_null(^"Gameplay/Devices/LidDrill") as DrillPoint
	if dp == null:
		push_error("[OFDRILL] no LidDrill")
		get_tree().quit(1)
		return
	rt.teleport_crew(0, Transform3D(Basis.IDENTITY, dp.global_position + Vector3(0, 30, 0)))  # out of the shot
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.fov = 70.0
	var side: Vector3 = dp.global_basis.x * 2.6 + dp.global_basis.z * 2.2
	cam.global_position = dp.global_position + side + Vector3(0, 1.1, 0)
	cam.look_at(dp.global_position + Vector3(0, -0.5, 0))
	cam.current = true
	for i: int in 30:
		await get_tree().physics_frame
	await _shot("of_lid_drill_1_before_place")
	dp.runner.place(-1, 360.0)
	for i: int in 20:
		await get_tree().physics_frame
	await _shot("of_lid_drill_2_placed")
	var bit: Vector3 = -dp.device_node.global_basis.z if dp.device_node != null else Vector3.ZERO
	print("[OFDRILL] spot %s -Z %s; device %s bit axis %s; rest visual %s" % [dp.global_position, -dp.global_basis.z,
		dp.device_node != null, bit, dp.visual_instance.name if dp.visual_instance != null else "-"])
	print("[OFDRILL] done: %s" % _out)
	get_tree().quit(0)


func _shot(label: String) -> void:
	for i: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, label])
