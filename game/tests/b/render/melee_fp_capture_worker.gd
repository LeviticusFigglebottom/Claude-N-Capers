## Worker for melee_fp_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const DEFAULT_IDS: Array[StringName] = [&"melee.sledgehammer", &"melee.fire_axe", &"melee.combat_dagger"]

var _out: String = ""
var _ids: Array[StringName] = []
var _range: FiringRange = null
var _tag: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/melee_fp"
	for i: int in range(1, args.size()):
		_ids.append(StringName(args[i]))
	if _ids.is_empty():
		_ids = DEFAULT_IDS.duplicate()
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(step: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%s.png" % [_out, _tag, step]
	img.save_png(path)
	var v: CrewView = CrewView.of(_range.crew)
	var fp: FpViewmodel = v.fp_viewmodel() if v != null else null
	var cm: Node = _range.crew.get_node_or_null("Melee")
	print("MELEE FP SHOT %s clip=%s action=%d melee_state=%s" % [path, fp.clip if fp != null else &"-",
			fp.action if fp != null else -1, cm.get(&"state") if cm != null else "-"])


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://melee_fp_profiles_%d" % OS.get_process_id()
	OnboardingTips.persist = false
	for id: StringName in _ids:
		_tag = String(id).trim_prefix("melee.")
		var p: PlayerProfile = PlayerProfile.new_default()
		p.loadout.melee = id
		SaveService.save_profile(p, SLOT)
		var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
		get_tree().root.add_child(flow)
		flow.show_home()
		await _wait(0.5)
		flow.main_menu.firing_range_requested.emit()
		await _wait(2.0)
		_range = flow.firing_range
		if _range == null or _range.crew == null:
			push_error("melee_fp_capture: no range with a crew")
			get_tree().quit(1)
			return
		_range.set_aim_mode(true)
		await _wait(1.0)
		await _shot("01_idle")
		Input.action_press(&"melee")
		await _wait(0.5)
		await _shot("02_charging")
		await _wait(0.7)
		await _shot("03_charged")
		Input.action_release(&"melee")
		await _wait(0.12)
		await _shot("04_charged_swing")
		await _wait(0.9)
		Input.action_press(&"melee")
		await _wait(0.08)
		Input.action_release(&"melee")
		await _wait(0.12)
		await _shot("05_quick_swing")
		await _wait(1.0)
		flow.close_firing_range()
		await _wait(0.3)
		flow.queue_free()
		await _wait(0.3)
	SaveService.delete_profile(SLOT)
	print("MELEE FP DONE")
	get_tree().quit(0)
