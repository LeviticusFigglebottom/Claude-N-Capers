## Worker for blueprint_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0

var _out: String = ""
var _heist: StringName = &"glasshouse"
## RT-B1: a staged heist (RT) is captured through the test-only fixture (tests/b/staged_heist_fixture.gd).
var _fx: RefCounted = preload("res://tests/b/staged_heist_fixture.gd").new()


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_heist = StringName(args[1]) if args.size() > 1 else &"glasshouse"
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/blueprints"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _shot(step: String, frames: int = 12) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%s_%dx%d.png" % [_out, _heist, step, img.get_width(), img.get_height()]
	img.save_png(path)
	print("BLUEPRINT SHOT ", path)


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://blueprint_capture_profiles"
	OnboardingTips.persist = false
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_fx.call(&"stage")
	var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(flow)
	flow.show_hub()
	flow.open_station(&"planning")
	await _shot("select", 6)
	flow.call(&"_on_heist_chosen", _heist, Enums.Difficulty.ROUTINE)
	await _shot("briefing", 6)
	flow.call(&"_on_briefing_continue", _heist, Enums.Difficulty.ROUTINE)
	# The pre-planning screen's view (the briefing's own blueprint stays in the tree, hidden); it opens on the entry
	# floor, then every other floor. Shots are named by floor index.
	var views: Array[Node] = get_tree().root.find_children("*", "BlueprintView", true, false).filter(
			func(v: Node) -> bool: return (v as Control).is_visible_in_tree())
	var view: Node = views[0] if not views.is_empty() else null
	var bp: PreplanBlueprint = (view.get(&"board") as PreplanBoard).blueprint if view != null else null
	var entry: int = bp.entry_floor() if bp != null else 0
	await _shot("floor%d" % entry, 20)
	if bp != null:
		print("BLUEPRINT entry floor %d, shown %d of %d" % [entry, int(view.get(&"floor_index")), bp.floor_count()])
		for f: int in range(bp.floor_count()):
			if f != entry:
				view.call(&"set_floor", f)
				await _shot("floor%d" % f, 8)
	await _payday_shot()
	print("BLUEPRINT DONE %s" % _heist)
	get_tree().quit(0)


## r280 screens pass: the heist's payday (the real PaydayScreen, nothing applied to the profile): a clear with three
## bags of the heist's first loot, its contract pay and the default crew of the sample result.
func _payday_shot() -> void:
	var def: HeistDef = HeistRegistry.get_def(_heist)
	if def == null:
		return
	var r: Dictionary = HeistCatalog.sample_result()
	var loot: Array = []
	var lid: StringName = def.loot[0] if not def.loot.is_empty() else &"loot.cash_bricks"
	for i: int in range(3):
		loot.append({"loot_id": lid, "value": int(LootManager.loot_info(lid).get("value", 0))})
	r.merge({"heist_id": _heist, "success": true, "contract_pay": def.base_payout, "loot": loot,
			"difficulty": Enums.Difficulty.HAZARDOUS}, true)
	for n: Node in get_tree().root.get_children():
		if n is MenuFlow:
			(n as MenuFlow).visible = false
	var pd: PaydayScreen = (load("res://content/ui/results/payday.tscn") as PackedScene).instantiate() as PaydayScreen
	pd.apply_to_profile = false
	get_tree().root.add_child(pd)
	pd.show_result(r)
	await get_tree().create_timer(4.0).timeout
	await _shot("payday", 10)
