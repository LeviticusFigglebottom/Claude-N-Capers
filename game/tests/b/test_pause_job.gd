## Lead queue (a): the in-heist pause menu's job card (heist, difficulty, current objective, loot) and the
## snapshot MenuOptions takes from the running HUD.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")


func test_job_card_fills() -> void:
	var p: PauseMenu = PauseMenu.new()
	add_child(p)
	await wait_frames(1)
	assert_false(p.job_card.visible, "no job yet")
	p.set_job({"heist_id": &"glasshouse", "difficulty": Enums.Difficulty.HAZARDOUS, "objective": "Open the safe",
		"bags": 2, "loot_value": 27800})
	assert_true(p.job_card.visible)
	assert_eq((p.job_labels[&"heist"] as Label).text, UiText.t(&"heist.glasshouse.name"))
	assert_eq((p.job_labels[&"objective"] as Label).text, "Open the safe")
	assert_eq((p.job_labels[&"loot"] as Label).text, UiText.t(&"ui.pause.loot_line", {"bags": 2, "value": UiText.money(27800)}))
	p.queue_free()


func test_snapshot_reads_the_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var model: MockHudModel = MockHudModel.new()
	add_child(model)
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	hud.auto_find_model = false
	hud.heist_id = &"glasshouse"
	layer.add_child(hud)
	await wait_frames(1)
	hud.bind(model)
	model.objectives = [{"id": &"safe", "text_key": &"objective.glasshouse.safe", "args": {},
		"state": Enums.ObjectiveState.ACTIVE}]
	EventBus.loot_secured.emit(11, &"loot.jewelry", 13000)
	var mo: MenuOptions = MenuOptions.new()
	mo.heist_layer = layer
	var info: Dictionary = mo.job_snapshot()
	assert_eq(info["heist_id"], &"glasshouse")
	assert_eq(info["objective"], UiText.t(&"objective.glasshouse.safe"))
	assert_eq(info["bags"], 1)
	assert_eq(info["loot_value"], 13000)
	mo.free()
	layer.queue_free()
	model.queue_free()
	await wait_frames(1)
