## Worker for device_timer_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const HEIST: StringName = &"glasshouse"
## Where the shooter stands: this far out of the drilled surface (m).
const STAND_OFF_M: float = 1.8

var _out: String = ""
var _n: int = 0
var _flow: MenuFlow = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/device_timer"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _shot(step: String, frames: int = 20) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_n += 1
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%02d_%s_%dx%d.png" % [_out, _n, step, img.get_width(), img.get_height()]
	img.save_png(path)
	print("DEVICE TIMER SHOT ", path)


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://device_timer_profiles"
	OnboardingTips.persist = false
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	_flow.launch(HEIST, Enums.Difficulty.ROUTINE, SaveService.load_profile(SLOT).loadout, 42)
	var t0: int = Time.get_ticks_msec()
	while _crew() == null and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	var crew: CrewController = _crew()
	var dp: DrillPoint = null
	for n: Node in get_tree().root.find_children("*", "DrillPoint", true, false):
		if (n as DrillPoint).device == DrillPoint.Device.DRILL:
			dp = n as DrillPoint
			break
	if crew == null or dp == null:
		push_error("device_timer_capture: crew %s drill point %s" % [crew, dp])
		get_tree().quit(1)
		return
	crew.set_masked()
	_stand_at(crew, dp)
	await _shot("before_place", 20)
	dp.runner.place(crew.slot, dp.effective_duration())
	_aim(crew, dp)
	await _shot("drill_running", 20)
	dp.runner.call(&"_jam")
	_aim(crew, dp)
	await _shot("drill_jammed", 20)
	dp.runner.fix(crew.slot)
	await _shot("drill_fixed", 20)
	print("DEVICE TIMER DONE %d frames" % _n)
	get_tree().quit(0)


## Put the crew `off` m in front of the drill point (out of the drilled surface, +Z), feet on the floor below.
func _stand_at(crew: CrewController, dp: DrillPoint, off: float = STAND_OFF_M) -> void:
	var out: Vector3 = dp.global_basis.z
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.BACK
	var p: Vector3 = dp.global_position + out * off
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 3.0)
	q.exclude = [crew.get_rid()]
	var hit: Dictionary = crew.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		p.y = (hit["position"] as Vector3).y + 0.05
	crew.teleport(Transform3D(Basis.IDENTITY, p))
	_aim(crew, dp)


func _aim(crew: CrewController, dp: DrillPoint) -> void:
	var d: Vector3 = (dp.global_position + Vector3.UP * 0.3 - crew.eye_position()).normalized()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-d.x, -d.z)
	i.look_pitch = asin(clampf(d.y, -1.0, 1.0))
	crew.look_yaw = i.look_yaw
	crew.look_pitch = i.look_pitch
	crew.apply_intent(i)
	crew.teleport(crew.global_transform)  # PlayerInput re-reads the crew's facing on teleport (PI-06)


func _crew() -> CrewController:
	for n: Node in get_tree().root.find_children("*", "CrewController", true, false):
		var c: CrewController = n as CrewController
		if c != null and c.slot == Net.local_slot() and not c.is_ai:
			return c
	return null
