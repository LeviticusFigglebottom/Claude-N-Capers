## Worker for hud_profile.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const HEIST: StringName = &"glasshouse"
const SAMPLE: int = 90

var _flow: MenuFlow = null


func _ready() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("HUDPROF ", s)


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://hud_profile_profiles"
	OnboardingTips.persist = false
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await get_tree().process_frame
	_flow.launch(HEIST, Enums.Difficulty.ROUTINE, SaveService.load_profile(SLOT).loadout, 42)
	var t0: int = Time.get_ticks_msec()
	while (_hud() == null or _flow.runtime == null) and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	var hud: Hud = _hud()
	if hud == null:
		_log("no HUD")
		get_tree().quit()
		return
	await _frames(60)
	_log("casing: with HUD %.2f ms" % await _avg_ms())
	var crew: CrewController = _local_crew()
	if crew != null:
		crew.set_masked()
	await _frames(60)
	var with_hud: float = await _avg_ms()
	_set_on(hud, false)
	var without: float = await _avg_ms()
	_set_on(hud, true)
	_log("masked: with HUD %.2f ms, without %.2f ms -> HUD %.2f ms / frame" % [with_hud, without, with_hud - without])
	var shares: Array[String] = []
	for c: Node in hud.get_children():
		if not c is CanvasItem:
			continue
		_set_on(c, false)
		var off: float = await _avg_ms()
		_set_on(c, true)
		shares.append("%s %.2f" % [c.name, with_hud - off])
	_log("per child (ms saved when off): " + " | ".join(shares))
	_log("objects %d nodes %d orphan %d" % [Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	SaveService.delete_profile(SLOT)
	get_tree().quit()


func _set_on(n: Node, on: bool) -> void:
	n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	(n as CanvasItem).visible = on


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().process_frame


func _avg_ms() -> float:
	await _frames(5)
	var total: float = 0.0
	for _i: int in range(SAMPLE):
		await get_tree().process_frame
		total += Performance.get_monitor(Performance.TIME_PROCESS)
	return total / SAMPLE * 1000.0


func _hud() -> Hud:
	for n: Node in get_tree().root.find_children("*", "Hud", true, false):
		if n is Hud and (n as Hud).model != null:
			return n as Hud
	return null


func _local_crew() -> CrewController:
	for n: Node in get_tree().root.find_children("*", "CrewController", true, false):
		var c: CrewController = n as CrewController
		if c != null and c.slot == Net.local_slot():
			return c
	return null
