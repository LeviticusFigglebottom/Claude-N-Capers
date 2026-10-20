extends Node

const SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var pd: PaydayScreen = SCENE.instantiate() as PaydayScreen
	pd.cards_enabled = false
	get_tree().root.add_child(pd)
	await get_tree().process_frame
	var ids: Array[StringName] = [&"achievement.first_score", &"achievement.of_quiet_weekend", &"achievement.of_no_harm_done"]
	var p: PlayerProfile = PlayerProfile.new_default()
	for a: AchievementDef in Achievements.all():
		if not ids.has(a.id):
			p.achievements[a.id] = {"progress": Achievements.target_of(a), "unlocked": true}
	pd.setup(p)
	var r: Dictionary = HeistCatalog.sample_result()
	r["success"] = true
	r["heist_id"] = &"ostrander_federal"
	pd.show_result(r)
	pd.achievements_unlocked = ids
	pd._render()
	for i: int in 6:
		await get_tree().process_frame
	print("PROBE focus_mode=", pd.achievements_panel.focus_mode)
	pd.continue_button.grab_focus()
	await get_tree().process_frame
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_up"
	ev.pressed = true
	get_viewport().push_input(ev)
	for i: int in 30:
		await get_tree().process_frame
	var f: Control = get_viewport().gui_get_focus_owner()
	print("PROBE focused=", f.name if f != null else "none")
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit(0)
