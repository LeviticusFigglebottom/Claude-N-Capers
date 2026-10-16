## X-5 windowed evidence (D-086): Gallery Night curator office (room CO, seed 5 = curator_office). The curator sits
## at his desk on CuratorChair (desk_work, a real seat); a staff member with desk_work at the seatless StaffCO
## point stands (teller_count, PO6-06 rule) instead of sitting on thin air. PNG goes to --cap-out. Owner: ENV A.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 1280x720 \
##     res://tests/a/e2e/x5_gn_desk_capture.tscn -- --cap-out=/abs/dir
extends Node3D

const STAFF_CO: Vector3 = Vector3(7.5, 5.45, 3.8)

var _out: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--cap-out="):
			_out = a.trim_prefix("--cap-out=")
	if _out == "":
		_out = OS.get_user_data_dir() + "/x5"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"gallery_night", 5, Enums.Difficulty.ROUTINE, self,
		{"crew_ai": false})
	if rt == null:
		push_error("[X5CAP] launch failed")
		get_tree().quit(1)
		return
	var staff: NpcBase = rt.spawn_npc(&"civilian", Transform3D(Basis(Vector3.UP, PI * 0.5), STAFF_CO),
		{"idle_activity": &"desk_work", "tags": [&"civ_curator"]})
	for i: int in 90:
		await get_tree().physics_frame
	for n: Node in rt.npcs(&"civilian"):
		var npc: NpcBase = n as NpcBase
		if npc.global_position.distance_to(Vector3(6.5, 5.4, 3.0)) < 4.5:
			var ad: AnimDriver = AnimDriver.of(npc)
			print("[X5CAP] %s %s act %s seat %s clip %s at %s" % [npc.name, npc.spawn_info.get("tags"),
				npc.spawn_info.get("idle_activity"), CivilianBrain.has_seat_under(npc),
				ad.choose_clip() if ad != null else &"-", npc.global_position])
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.fov = 70.0
	cam.global_position = Vector3(9.6, 7.4, 5.7)
	cam.look_at(Vector3(6.6, 6.1, 2.2))
	cam.current = true
	for i: int in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/x5_gn_curator_seated_staff_standing.png" % _out)
	print("[X5CAP] done: %s (staff %s)" % [_out, staff.name if staff != null else "-"])
	get_tree().quit(0)
