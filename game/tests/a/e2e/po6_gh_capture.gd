## PO6 windowed evidence (D-086), Golden Hour: the workshop safe closed (no loot visible, PO6-05), the drill
## placed once (PO6-01), the safe open with its loot inside (PO6-05), a kneeling cuffed hostage and the same
## hostage after a lethal hit, dead in place (PO6-18), the settled corpse shot twice (blood at the hit points, PO6-19).
## PNGs go to --cap-out. Owner: ENV A.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 \
##     res://tests/a/e2e/po6_gh_capture.tscn -- --cap-out=/abs/dir
extends Node

var _out: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--cap-out="):
			_out = a.trim_prefix("--cap-out=")
	if _out == "":
		_out = OS.get_user_data_dir() + "/po6_gh"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"glasshouse", 1792002290, Enums.Difficulty.ROUTINE, self,
		{"skip_casing": true, "crew_ai": false})
	var safe: Safe = rt.find_child("WorkshopSafe", true, false) as Safe
	if safe == null:
		push_error("[PO6CAP] no WorkshopSafe")
		get_tree().quit(1)
		return
	rt.teleport_crew(0, Transform3D(Basis.IDENTITY, safe.global_transform * Vector3(0, 0.05, -6.0)))
	var cam: Camera3D = Camera3D.new()
	rt.add_child(cam)
	cam.global_position = safe.global_transform * Vector3(0.6, 1.5, -2.3)
	cam.look_at(safe.global_position + Vector3(0, 0.5, 0))
	cam.current = true
	var fill: OmniLight3D = OmniLight3D.new()
	rt.add_child(fill)
	fill.global_position = safe.global_transform * Vector3(0, 2.0, -1.5)
	fill.omni_range = 5.0
	fill.light_energy = 1.5
	await _wait(2.0)
	_log_contents(safe, "closed")
	await _shot("01_safe_closed")
	var dp: DrillPoint = safe.find_child("SafeDrill", true, false) as DrillPoint
	dp.runner.place(0, dp.effective_duration())
	dp.runner.jams.clear()
	await _wait(1.5)
	print("[PO6CAP] drill state %d device_node %s" % [dp.runner.state, dp.device_node])
	await _shot("02_drill_placed_once")
	dp.runner.progress = 0.999
	# P's PO6 rerun: shot 03 was taken before the safe was open. Wait for the opened state (the drill finishes ->
	# open_by_device -> swing_open), then let the door and the loot settle a moment before the shot.
	if not await _wait_opened(safe, dp, 20.0):
		push_error("[PO6CAP] safe not open 20 game s after the drill was set to finish (drill state %d, stage %d)" % [
			dp.runner.state, safe.stage])
		get_tree().quit(1)
		return
	await _wait(1.0)
	_log_contents(safe, "open")
	await _shot("03_safe_open_loot_inside")
	var civ: NpcBase = rt.spawn_npc(&"civilian",
		Transform3D(safe.global_basis, safe.global_transform * Vector3(-1.1, 0.05, -1.2)), {})
	var brain: Node = civ.get_node("Brain")
	brain.set_physics_process(false)
	brain.set_process(false)
	brain.set(&"anim_hint", &"kneel_cuffed")
	cam.global_position = safe.global_transform * Vector3(-0.2, 1.4, -3.4)
	cam.look_at(civ.global_position + Vector3(0, 0.5, 0))
	await _wait(1.5)
	await _shot("04_hostage_kneel_cuffed")
	# A real shot is heard (S3.1 gunshot noise): bystanders (the jeweler) panic like in play.
	var shooter: CrewController = rt.crew_controller(0) as CrewController
	rt.make_noise(civ.global_position + Vector3(0, 1, 0), Tweak.stealth().gunshot_player_radius_m, &"gunshot",
		shooter.net_id)
	civ.take_hit({"amount": 5000.0, "direction": -safe.global_basis.x, "type": Enums.DamageType.BULLET})
	await _wait(2.0)
	var d: AnimDriver = AnimDriver.of(civ)
	print("[PO6CAP] hostage death clip %s" % (d.clip if d != null else &"-"))
	await _shot("05_hostage_shot_dies_in_place")
	# PO6-19: the corpse, once settled, shot twice in the back: blood at the hit points (C's blood_hit VFX).
	await _wait(4.0)
	var chest: Vector3 = civ.global_position + Vector3(0, 0.25, 0)
	var rd: NpcRagdoll = NpcRagdoll.of(civ)
	if rd != null and not rd.bodies.is_empty():
		chest = rd.bodies[0].global_position + Vector3(0, 0.1, 0)
	for i: int in 2:
		civ.take_hit(Damage.info(30.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"weapon.kestrel_p9",
			chest + Vector3(0.08 * i, 0, 0), Vector3(0, -0.6, -1).normalized()))
		await _wait(0.4)
	cam.global_position = chest + safe.global_basis * Vector3(0.9, 1.3, -1.3)
	cam.look_at(chest)
	await _wait(1.0)
	await _shot("06_corpse_shot_blood_at_hit")
	print("[PO6CAP] done: %s" % _out)
	get_tree().quit(0)


func _log_contents(safe: Safe, tag: String) -> void:
	for p: GameplayPrefab in safe.contents():
		print("[PO6CAP] %s: %s visible %s enabled %s" % [tag, p.name, p.is_visible_in_tree(), p.interactable.enabled])


## Polls until `safe.opened` (true) or `timeout_s` game seconds pass (false). A jam on the way is fixed at once
## (the capture is about the open safe, not the jam schedule).
func _wait_opened(safe: Safe, dp: DrillPoint, timeout_s: float) -> bool:
	var t: float = 0.0
	while not safe.opened and t < timeout_s:
		if dp.runner.state == DeviceRunner.State.JAMMED:
			dp.runner.fix(0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	print("[PO6CAP] safe opened=%s after %.1f game s (drill state %d)" % [safe.opened, t, dp.runner.state])
	return safe.opened


## Game seconds (scaled physics time), not wall time: under llvmpipe a wall-clock timer can end well under 1 game s.
func _wait(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, tag])
	print("[PO6CAP] shot %s" % tag)
