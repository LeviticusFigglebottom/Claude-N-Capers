## D-116 review capture (windowed): a police officer aims while walking and running (aim_rifle_walk / _run layered over
## the legs), reloads a shotgun standing (reload_shotgun), then reloads an LMG while walking (reload_lmg on the upper
## body). A frame every CAPTURE_S goes to --anim-out as NNN.png; the clip and layer print per frame. Owner: ENV A.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 640x480 \
##     res://tests/a/e2e/d116_police_combat_capture.tscn -- --anim-out=/abs/dir
extends Node

const CAPTURE_S: float = 0.1

var _out: String = ""
var _frame: int = 0
var _cop: NpcBase = null
var _vel: Vector3 = Vector3.ZERO
var _cam: Camera3D = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--anim-out="):
			_out = a.trim_prefix("--anim-out=")
	if _out == "":
		_out = OS.get_user_data_dir() + "/d116_police_combat"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_map", 7, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 40)))
	var cop: NpcBase = rt.spawn_npc(&"police", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.05, 0)), {})
	var brain: Node = cop.get_node("Brain")
	brain.set_physics_process(false)
	for n: String in ["Motor", "Gunner"]:
		var c: Node = cop.get_node_or_null(n)
		if c != null:
			c.set_physics_process(false)
			c.set_process(false)
	cop.set_physics_process(false)
	_cop = cop
	_cam = Camera3D.new()
	rt.add_child(_cam)
	_cam.current = true
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	rt.add_child(sun)
	sun.rotation_degrees = Vector3(-40, 150, 0)
	sun.light_energy = 2.0
	var d: AnimDriver = AnimDriver.of(cop)
	brain.set(&"anim_hint", &"aim")
	await _frames(0.6, Vector3.ZERO)
	await _frames(2.0, Vector3(-1.6, 0, 0))  # facing -X (yaw 90 deg): walking forward, aiming
	await _frames(1.2, Vector3(-3.5, 0, 0))  # running, aiming
	await _frames(0.6, Vector3.ZERO)
	brain.set(&"anim_hint", &"idle_alert")
	d.weapon_class = Enums.WeaponClass.SHOTGUN
	EventBus.audio_cue_requested.emit(NpcGunner.CUE_RELOAD_RIFLE, Vector3.ZERO, cop.net_id)
	await _frames(CombatTweak.data().npc_reload_s + 0.3, Vector3.ZERO)
	d.weapon_class = Enums.WeaponClass.LMG
	await _frames(0.4, Vector3(-1.6, 0, 0))
	EventBus.audio_cue_requested.emit(NpcGunner.CUE_RELOAD_RIFLE, Vector3.ZERO, cop.net_id)
	await _frames(CombatTweak.data().npc_reload_s + 0.3, Vector3(-1.6, 0, 0))
	print("[D116CAP] %d frames in %s" % [_frame, _out])
	get_tree().quit(0)


func _frames(seconds: float, vel: Vector3) -> void:
	var t: float = 0.0
	_vel = vel
	while t < seconds:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%03d.png" % [_out, _frame])
		var d: AnimDriver = AnimDriver.of(_cop)
		print("[D116CAP] frame %03d clip %s layer %s w=%.2f t=%.3f base_t=%.3f" % [_frame, d.clip, d.hold_layer.clip,
			d.hold_layer.influence, d.hold_layer.time, d.player.current_animation_position])
		_frame += 1
		var step: float = 0.0  # CAPTURE_S of game time between frames
		while step < CAPTURE_S:
			await get_tree().physics_frame
			var dt: float = get_physics_process_delta_time()
			_cop.velocity = _vel
			_cop.global_position += _vel * dt
			step += dt
		t += step
		var p: Vector3 = _cop.global_position
		_cam.global_position = p + Vector3(-1.2, 1.4, 2.4)  # front-left three-quarter, following
		_cam.look_at(p + Vector3(0, 1.0, 0))
