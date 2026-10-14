## Worker for bag_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const HEIST: StringName = &"glasshouse"

var _out: String = ""
var _n: int = 0
var _flow: MenuFlow = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/bag_capture"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _log(s: String) -> void:
	print("BAG ", s)


func _shot(shot: String, frames: int = 12) -> void:
	var t0: int = Time.get_ticks_msec()
	for _i: int in range(frames):
		await get_tree().process_frame
	_log("%d frames in %d ms" % [frames, Time.get_ticks_msec() - t0])
	await RenderingServer.frame_post_draw
	_n += 1
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%02d_%s_%dx%d.png" % [_out, _n, shot, img.get_width(), img.get_height()]
	img.save_png(path)
	_log("shot " + path.get_file())


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://bag_capture_profiles"
	OnboardingTips.persist = false
	for id: StringName in OnboardingTips.ALL:
		OnboardingTips.mark_seen(id)
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await get_tree().process_frame
	_flow.launch(HEIST, Enums.Difficulty.ROUTINE, SaveService.load_profile(SLOT).loadout, 42)
	var t0: int = Time.get_ticks_msec()
	while (_flow.runtime == null or get_viewport().get_camera_3d() == null) and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	await _stage()
	SaveService.delete_profile(SLOT)
	_log("done")
	get_tree().quit(0)


func _stage() -> void:
	var rt: HeistRuntime = _flow.runtime as HeistRuntime
	var loot: LootManager = rt.service(G.SVC_LOOT) as LootManager
	var cam: Camera3D = get_viewport().get_camera_3d()
	var mate: CrewController = null
	var me: CrewController = null
	for n: Node in get_tree().root.find_children("*", "CrewController", true, false):
		var c: CrewController = n as CrewController
		if c.slot == Net.local_slot():
			me = c
		elif mate == null:
			mate = c
	if loot == null or mate == null or me == null:
		_log("FAIL loot %s mate %s me %s" % [loot, mate, me])
		return
	await _shot("start", 10)
	# The spawn faces the shop window: look the other way, down the open street, from the player's eye.
	var fwd: Vector3 = cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP)
	var floor_y: float = me.global_position.y
	var base: Vector3 = Vector3(cam.global_position.x, floor_y, cam.global_position.z)
	var shot_cam: Camera3D = Camera3D.new()
	shot_cam.fov = cam.fov
	get_tree().root.add_child(shot_cam)
	shot_cam.global_position = base + Vector3.UP * 1.7 - fwd * 0.5
	shot_cam.look_at(base + fwd * 3.0 + Vector3.UP * 0.8, Vector3.UP)
	shot_cam.make_current()
	mate.process_mode = Node.PROCESS_MODE_DISABLED  # stands still for the photo; the bag is its child
	mate.global_position = base + fwd * 3.0
	mate.look_at(mate.global_position + fwd, Vector3.UP)
	var gold: LootBag = loot.spawn_bag(&"loot.gold", Transform3D(Basis(), mate.global_position + Vector3.UP))
	_log("carry gold -> %s" % loot.carry(gold, mate))
	loot.spawn_bag(&"loot.jewelry", Transform3D(Basis(), base + fwd * 2.2 - right * 1.2 + Vector3.UP * 0.3))
	loot.spawn_bag(&"loot.cash_bricks", Transform3D(Basis(), base + fwd * 2.4 + right * 1.2 + Vector3.UP * 0.3))
	for b: LootBag in loot.bags():
		var vis: Node = b.find_child("Bag", true, false)
		_log("bag %s weight %d visual Bag=%s" % [b.loot_id, b.weight, vis != null])
	await _shot("carried_and_dropped", 20)
	mate.process_mode = Node.PROCESS_MODE_INHERIT
	_log("throw -> %s" % loot.drop_bag(mate, true))
	await _shot("thrown", 20)
