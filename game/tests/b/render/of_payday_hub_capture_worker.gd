extends Node

const OF: StringName = &"ostrander_federal"

var _out: String = ""
var _difficulty: int = 2


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/of_payday_hub"
	if args.size() > 1:
		_difficulty = int(args[1])
	DirAccess.make_dir_recursive_absolute(_out)
	SaveService.root_dir = "user://of_payday_hub_profiles_%d" % OS.get_process_id()  # never the player's profile
	_run.call_deferred()


func _run() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var pd: PaydayScreen = (load("res://content/ui/results/payday.tscn") as PackedScene).instantiate() as PaydayScreen
	pd.cards_enabled = false
	get_tree().root.add_child(pd)
	await _frames(2)
	pd.setup(p)
	pd.show_result(_result())
	pd.skip_count()
	await _frames(12)
	print("OFPH PAYDAY d%d xp %d -> %d level %d payout=%s" % [_difficulty, pd.xp_before, pd.xp_after, p.level, pd.payout])
	print("OFPH PAYDAY achievements=%s freshness=%s" % [pd.achievements_unlocked, pd.freshness_eval])
	await _save("payday_d%d" % _difficulty)
	pd.queue_free()
	var hub: HubMenu = (load("res://content/ui/hub/hub_menu.tscn") as PackedScene).instantiate() as HubMenu
	get_tree().root.add_child(hub)
	hub.setup(p)
	await _frames(8)
	await _save("hub_d%d" % _difficulty)
	print("OFPH DONE")
	get_tree().quit(0)


## A HeistRuntime-shaped first OF stealth clear (as test_of_payday_e2e).
func _result() -> Dictionary:
	var r: Dictionary = HeistCatalog.sample_result()
	var loot: Array = []
	for b: Array in [[&"loot.cash_bricks", 4], [&"loot.bearer_bonds", 2]]:
		for i: int in range(int(b[1])):
			loot.append({"loot_id": b[0], "value": int(LootManager.loot_info(b[0]).get("value", 0))})
	var crew: Array = []
	for slot: int in range(4):
		crew.append({"slot": slot, "is_ai": slot > 0, "name": "", "kills": 0, "specials_killed": 0, "downs": 0,
			"civilians_killed": 0, "shots": 0, "hits": 0, "headshots": 0, "in_custody": false, "escaped": true})
	r.merge({"heist_id": OF, "success": true, "stealth": true, "time_s": 1260.0, "difficulty": _difficulty,
		"contract_pay": HeistRegistry.get_def(OF).base_payout, "loot": loot, "small_loot": 2400, "crew": crew,
		"pagers_answered": 1, "fail_reason": &"", "loot_available": 8}, true)
	return r


func _save(stem: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, stem, img.get_width(), img.get_height()]
	img.save_png(path)
	print("OFPH SHOT ", path)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
