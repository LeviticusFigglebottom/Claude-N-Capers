## Worker for coop_capture.gd (loaded at runtime so autoloads exist when it compiles). Drives one peer
## (host or client) through the co-op flow with the real screens and the real Net autoload, saving a
## PNG at each step and printing "COOP <role> <event>" lines so the two logs can be read side by side.
extends Node

const SLOT: int = 0
const HEIST: StringName = &"glasshouse"
const WAIT_S: float = 600.0

var _out: String = ""
var _role: String = "host"
var _port: int = 24601
## "leave" (default: the client leaves, then the host) or "success" (the host secures two bags through the
## real loot path and ends the heist won; both peers must reach the success payday).
var _mode: String = "leave"
var _secured: int = 0
var _n: int = 0
var _flow: MenuFlow = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/coop"
	_role = args[1] if args.size() > 1 else "host"
	_port = int(args[2]) if args.size() > 2 else 24601
	_mode = args[3] if args.size() > 3 else "leave"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _log(event: String) -> void:
	print("COOP %s %.1f %s" % [_role, Time.get_ticks_msec() / 1000.0, event])


func _shot(shot: String, frames: int = 12) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_n += 1
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%02d_%s_%dx%d.png" % [_out, _role, _n, shot, img.get_width(), img.get_height()]
	img.save_png(path)
	_log("shot " + path.get_file())


## Waits until `cond` is true or `timeout_s` passes; logs and returns false on a timeout.
func _wait(cond: Callable, what: String, timeout_s: float = WAIT_S) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not bool(cond.call()):
		if Time.get_ticks_msec() - t0 > int(timeout_s * 1000.0):
			_log("TIMEOUT " + what)
			return false
		await get_tree().process_frame
	_log("ok " + what)
	return true


func _seconds(s: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await get_tree().process_frame


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://coop_%s_profiles" % _role
	OnboardingTips.persist = false
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = "Host" if _role == "host" else "Client"
	SaveService.save_profile(p, SLOT)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await _seconds(1.0)
	_flow.show_hub()
	_flow.show_lobby()
	await _shot("lobby_connect")
	if _role == "host":
		await _host()
	else:
		await _client()
	_log("done")
	SaveService.delete_profile(SLOT)
	get_tree().quit()


func _humans() -> int:
	return _flow.lobby.state.human_slots().size() if _flow.lobby != null else 0


func _host() -> void:
	var ls: LobbyScreen = _flow.lobby_screen
	ls.host_port_edit.text = str(_port)
	_log("host() -> %s" % error_string(ls.host()))
	await _shot("lobby_hosted")
	if not await _wait(func() -> bool: return _humans() >= 2, "client joined"):
		return
	await _shot("lobby_two_humans")
	_log("set_contract -> %s" % _flow.lobby.set_contract(HEIST, Enums.Difficulty.ROUTINE, false))
	_flow.lobby.set_ready(true)
	if not await _wait(func() -> bool: return _flow.lobby.state.can_start(), "both ready", 180.0):
		_log("start_block %s" % _flow.lobby.state.start_block())
		await _shot("lobby_cannot_start")
		return
	await _shot("lobby_ready")
	_log("start() -> %s" % ls.start())
	if not await _wait(func() -> bool: return _flow.runtime != null and _hud() != null, "host in heist"):
		await _shot("host_no_heist")
		return
	_diag()
	await _shot("heist_host", 5)
	await _seconds(30.0)
	_diag()
	if _mode == "success":
		await _host_success()
		return
	await _wait(func() -> bool: return Net.human_slots().size() <= 1, "client left (Net)", 900.0)
	_diag()
	await _shot("host_after_client_left", 5)
	var pm: PauseMenu = _flow.options_menu.open_pause()
	await _shot("host_pause")
	if pm != null:
		pm.leave_requested.emit()
	await _end_on_payday()


## Test hook (lead): two bags spawned inside the secure zone are secured by LootManager's own rest rule
## (loot_secured [R] reaches the client), then the heist ends won for every human slot.
func _host_success() -> void:
	var rt: HeistRuntime = _flow.runtime as HeistRuntime
	var loot: Node = rt.service(G.SVC_LOOT)
	var zone: Node3D = null
	for n: Node in get_tree().get_nodes_in_group(G.LOOT_SECURE_ZONE):
		if n is Node3D and rt.is_ancestor_of(n):
			zone = n as Node3D
			break
	if loot == null or zone == null:
		_log("no loot service / secure zone")
		return
	EventBus.loot_secured.connect(func(_id: int, _loot: StringName, _value: int) -> void: _secured += 1)
	var at: Vector3 = zone.global_position
	for c: Node in zone.get_children():
		if c is CollisionShape3D:
			at = (c as CollisionShape3D).global_position  # the zone's volume, not its origin (ZoneUtil.contains)
			break
	_log("secure zone %s at %s" % [zone.name, at])
	for id: StringName in [&"loot.jewelry", &"loot.cash"]:
		loot.call(&"spawn_bag", id, Transform3D(Basis(), at + Vector3(0, 0.3, 0)))
	await _wait(func() -> bool: return _secured >= 2, "two bags secured", 300.0)
	await _shot("host_secured", 5)
	_log("end_heist(true) -> %s" % str(rt.end_heist(true, Net.human_slots(), &"")).left(120))
	await _end_on_payday()


func _client() -> void:
	var ls: LobbyScreen = _flow.lobby_screen
	ls.join_port_edit.text = str(_port)
	var joined: Callable = func() -> bool: return _humans() >= 2
	for _i: int in range(40):
		_log("join_loopback() -> %s" % error_string(ls.join_loopback()))
		if await _wait(joined, "joined", 6.0):
			break
		_flow.lobby.leave()
	await _shot("lobby_joined")
	if not await _wait(func() -> bool: return not _flow.lobby.state.contract.is_empty(), "contract from host", 120.0):
		return
	_flow.lobby.set_ready(true)
	await _shot("lobby_ready")
	if not await _wait(func() -> bool: return _flow.runtime != null and _hud() != null, "client in heist"):
		await _shot("client_no_heist")
		return
	_diag()
	await _shot("heist_client", 5)
	await _seconds(30.0)
	_diag()
	if _mode == "success":
		await _end_on_payday(1800.0)
		return
	await _shot("heist_client_later", 5)
	var pm: PauseMenu = _flow.options_menu.open_pause()
	await _shot("client_pause")
	if pm != null:
		pm.leave_requested.emit()
	await _end_on_payday()


## After leaving: the payday (if any) and home.
func _end_on_payday(timeout_s: float = 120.0) -> void:
	var payday: Callable = func() -> bool:
		var pd: PaydayScreen = _flow.get(&"_heist_payday") as PaydayScreen
		return pd != null and is_instance_valid(pd) and pd.visible
	if await _wait(payday, "payday shown", timeout_s):
		await _shot("payday", 30)
		var pd: PaydayScreen = _flow.get(&"_heist_payday") as PaydayScreen
		_log("payday success=%s reason=%s" % [pd.payout.get("success"), pd.result.get("fail_reason", "")])
		pd.continue_button.pressed.emit()
	await _seconds(3.0)
	await _shot("after_leave")
	_log("home visible=%s runtime=%s coop=%s" % [_flow.visible, _flow.runtime, _flow.is_coop()])


## One line of state to compare host and client: humans in the lobby / Net, crew slots, HUD model fields.
func _diag() -> void:
	var crew: Array[String] = []
	for slot: int in Net.all_slots():
		var c: Dictionary = Net.crew[slot] as Dictionary
		crew.append("%d:%s" % [slot, "ai" if bool(c.get("is_ai", true)) else "human"])
	var h: Hud = _hud()
	var objs: Variant = h.model.get(&"objectives") if h != null else null
	var mates: Variant = h.model.get(&"crew") if h != null else null
	_log("diag lobby_humans=%d net_humans=%s local=%d crew=[%s] model_objectives=%s model_crew=%s hud_obj_vis=%s" % [
		_humans(), Net.human_slots(), Net.local_slot(), ",".join(crew),
		(objs as Array).size() if objs is Array else str(objs), (mates as Array).size() if mates is Array else str(mates),
		h.objectives.visible if h != null else false])


func _hud() -> Hud:
	for n: Node in get_tree().root.find_children("*", "Hud", true, false):
		if n is Hud and (n as Hud).model != null:
			return n as Hud
	return null
