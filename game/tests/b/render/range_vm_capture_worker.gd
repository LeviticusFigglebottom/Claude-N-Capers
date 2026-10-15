## Worker for range_vm_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const CORSAIR: StringName = &"weapon.corsair_ar"
const P9: StringName = &"weapon.kestrel_p9"
const PLOWMAN: StringName = &"weapon.plowman_12"

var _out: String = ""
var _n: int = 0
var _range: FiringRange = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/range_vm"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(step: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%02d_%s.png" % [_out, _n, step]
	img.save_png(path)
	var fp: FpViewmodel = _fp()
	var wv: WeaponVisual = _range.viewmodel
	var a: Dictionary = RangeCrewBridge.ammo(_range.crew)
	print("RANGE VM SHOT %s weapon=%s fp_weapon=%s clip=%s action=%d ads=%.2f mag=%s reloading=%s" % [path,
			_range.current_weapon_id(), wv.weapon.id if wv != null and wv.weapon != null else &"-",
			fp.clip if fp != null else &"-", fp.action if fp != null else -1, fp.ads_weight if fp != null else 0.0,
			a.get("mag", "-"), a.get("reloading", "-")])


func _fp() -> FpViewmodel:
	var v: CrewView = CrewView.of(_range.crew)
	return v.fp_viewmodel() if v != null else null


func _press(action: StringName, hold_s: float) -> void:
	Input.action_press(action)
	await _wait(hold_s)
	Input.action_release(action)


## Fire / reload / ADS of the weapon in hand, with frames inside each clip.
func _exercise(tag: String) -> void:
	await _shot(tag + "_idle")
	Input.action_press(&"fire")
	await _wait(0.06)
	await _shot(tag + "_fire")
	await _wait(0.25)
	await _shot(tag + "_fire_hold")
	Input.action_release(&"fire")
	await _wait(0.4)
	var st: WeaponStats = _range.weapon_stats
	Input.action_press(&"reload")
	await _wait(0.1)
	Input.action_release(&"reload")
	var rt: float = st.reload_time_s if st != null else 2.0
	await _wait(rt * 0.3)
	await _shot(tag + "_reload_30")
	await _wait(rt * 0.35)
	await _shot(tag + "_reload_65")
	await _wait(rt * 0.45)
	Input.action_press(&"aim")
	await _wait(0.7)
	await _shot(tag + "_ads")
	Input.action_press(&"fire")
	await _wait(0.06)
	await _shot(tag + "_ads_fire")
	Input.action_release(&"fire")
	await _wait(0.3)
	Input.action_release(&"aim")
	await _wait(0.6)


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://range_vm_profiles"
	OnboardingTips.persist = false
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(flow)
	flow.show_home()
	await _wait(0.5)
	flow.main_menu.firing_range_requested.emit()
	await _wait(2.0)
	for n: Node in get_tree().root.find_children("*", "FiringRange", true, false):
		_range = n as FiringRange
	if _range == null or _range.crew == null:
		push_error("range_vm_capture: no range with a crew")
		get_tree().quit(1)
		return
	await _shot("enter_panel")
	_range.select_weapon(CORSAIR)
	_range.set_aim_mode(true)
	await _wait(0.12)
	await _shot("corsair_draw")
	await _wait(1.2)
	await _exercise("corsair")
	Input.action_press(&"slot_secondary")
	await _wait(0.05)
	Input.action_release(&"slot_secondary")
	await _wait(0.1)
	await _shot("swap_to_p9_holster")
	await _wait(0.4)
	await _shot("swap_to_p9_draw")
	await _wait(0.8)
	await _exercise("p9")
	_range.select_weapon(PLOWMAN)
	await _wait(0.15)
	await _shot("pick_plowman_swap")
	await _wait(1.4)
	await _exercise("plowman")
	Input.action_press(&"slot_secondary")
	await _wait(0.05)
	Input.action_release(&"slot_secondary")
	await _wait(1.2)
	await _shot("back_to_p9")
	print("RANGE VM DONE %d frames" % _n)
	get_tree().quit(0)
