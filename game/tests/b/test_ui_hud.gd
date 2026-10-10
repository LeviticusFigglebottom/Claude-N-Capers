## B1-04: the HUD binds to MockHudModel (the LocalHudModel stand-in) and updates on its signals.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")

var _hud: Hud
var _model: MockHudModel


func before_each() -> void:
	_model = MockHudModel.new()
	add_child(_model)
	_hud = HUD_SCENE.instantiate() as Hud
	_hud.auto_find_model = false
	add_child(_hud)
	await wait_frames(1)
	_hud.bind(_model)


func after_each() -> void:
	_hud.queue_free()
	_model.queue_free()
	await wait_frames(1)


func test_ammo_updates_on_signal() -> void:
	_model.ammo = {Enums.WeaponSlot.SECONDARY: {"mag": 9, "reserve": 77}}
	assert_eq(_hud.ammo.ammo_label.text, UiText.t(&"ui.hud.ammo", {"mag": 9, "reserve": 77}))
	_model.ammo = {Enums.WeaponSlot.SECONDARY: {"mag": 3, "reserve": 70}}
	assert_eq(_hud.ammo.ammo_label.text, UiText.t(&"ui.hud.ammo", {"mag": 3, "reserve": 70}))


func test_vitals_and_downs() -> void:
	_model.max_health = 200.0
	_model.health = 50.0
	_model.downs_left = 1
	assert_near(_hud.vitals.health_bar.value, 0.25)
	assert_eq(_hud.vitals.health_label.text, "50")
	assert_eq(_hud.vitals.downs_label.text, UiText.t(&"ui.hud.downs_left", {"count": 1}))
	_model.bleedout_s = 12.2
	_model.crew_state = Enums.CrewState.DOWNED
	assert_true(_hud.vitals.state_label.visible, "bleedout shown when downed")


func test_interaction_prompt_and_blocked_reason() -> void:
	assert_false(_hud.interaction.visible, "hidden without a prompt")
	_model.interaction = {"text_key": &"ui.prompt.answer_pager", "args": {"key": "F"}, "progress": 0.4,
			"blocked_reason": &""}
	assert_true(_hud.interaction.visible)
	assert_eq(_hud.interaction.prompt_label.text, UiText.t(&"ui.prompt.answer_pager", {"key": "F"}))
	assert_near(_hud.interaction.progress_bar.value, 0.4)
	assert_false(_hud.interaction.blocked_label.visible)
	_model.interaction = {"text_key": &"ui.prompt.pick_lock", "args": {"key": "F"}, "progress": 0.0,
			"blocked_reason": &"ui.prompt.blocked.casing"}
	assert_eq(_hud.interaction.blocked_label.text, UiText.t(&"ui.prompt.blocked.casing"))


func test_detection_chevron_colors() -> void:
	_model.detection = [
		{"observer_net_id": 1, "world_pos": Vector3(0, 0, -5), "value": 0.2, "kind": Enums.ObserverKind.GUARD},
		{"observer_net_id": 2, "world_pos": Vector3(5, 0, 0), "value": 0.6, "kind": Enums.ObserverKind.CAMERA},
		{"observer_net_id": 3, "world_pos": Vector3(0, 0, 5), "value": 1.0, "kind": Enums.ObserverKind.GUARD},
	]
	var c: Array[Dictionary] = _hud.chevrons.chevrons
	assert_eq(c.size(), 3, "one chevron per observer")
	var tw: HudTweak = HudTweak.load_default()
	assert_eq(c[0]["color"], tw.detection_blue)
	assert_eq(c[1]["color"], tw.detection_orange)
	assert_eq(c[2]["color"], tw.detection_red)
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.current = true
	assert_near(DetectionChevrons.screen_angle(cam, Vector3(0, 0, -5)), 0.0, 0.001, "ahead = up")
	assert_near(DetectionChevrons.screen_angle(cam, Vector3(5, 0, 0)), PI / 2.0, 0.001, "right")
	cam.queue_free()
	_model.detection = []
	assert_eq(_hud.chevrons.chevrons.size(), 0)


func test_pager_objectives_assault_bag_crew_mask() -> void:
	_model.pagers = [{"pager_id": 4, "time_left_s": 8.0, "answering": false, "progress": 0.0}]
	assert_eq(_hud.pager.pager_labels[0].text, UiText.t(&"ui.hud.pager", {"seconds": UiText.clock(8.0)}))
	_model.objectives = [{"id": &"a", "text_key": &"objective.glasshouse.find_keycard", "args": {},
			"state": Enums.ObjectiveState.ACTIVE}]
	assert_true(_hud.objectives.visible)
	assert_eq(_hud.objectives.list_box.get_child_count(), 1)
	_model.assault_phase = Enums.AssaultPhase.BUILD
	_model.assault_wave = 2
	assert_true(_hud.assault.visible)
	assert_eq(_hud.assault.phase_label.text, UiText.t(&"ui.hud.assault_phase.build"))
	_model.carried_bag = {"loot_id": &"loot.jewelry", "weight": Enums.LootWeight.LIGHT}
	assert_true(_hud.status.bag_label.visible)
	_model.crew = [{"slot": 2, "name": "Dutch", "is_ai": true, "health_frac": 0.5, "armor_frac": 0.0,
			"state": Enums.CrewState.NORMAL, "downs_left": 3, "carried_loot_id": &""}]
	assert_eq((_hud.teammates.name_labels[2] as Label).text, "Dutch")
	_model.casing = true
	_model.masked = false
	assert_eq(_hud.status.mask_label.text, UiText.t(&"ui.hud.unmasked"))


func test_finds_model_via_group() -> void:
	assert_true(_model.is_in_group(G.LOCAL_HUD_MODEL), "mock joins the LocalHudModel group")
	var h: Hud = HUD_SCENE.instantiate() as Hud
	add_child(h)
	assert_true(await wait_until(func() -> bool: return h.model != null, 2.0), "HUD discovers the model")
	assert_eq(h.model, _model as Node)
	_model.ammo = {Enums.WeaponSlot.SECONDARY: {"mag": 4, "reserve": 40}}
	assert_eq(h.ammo.ammo_label.text, UiText.t(&"ui.hud.ammo", {"mag": 4, "reserve": 40}))
	h.queue_free()


func test_rediscovers_after_model_freed() -> void:
	var h: Hud = HUD_SCENE.instantiate() as Hud
	add_child(h)
	assert_true(await wait_until(func() -> bool: return h.model == _model, 2.0), "bound to the first model")
	_model.queue_free()
	var next: MockHudModel = MockHudModel.new()
	add_child(next)
	assert_true(await wait_until(func() -> bool: return h.model == next, 2.0), "rebinds to the new model")
	_model = next  # after_each frees it
	h.queue_free()


func test_no_model_no_binding() -> void:
	_model.remove_from_group(G.LOCAL_HUD_MODEL)
	var h: Hud = HUD_SCENE.instantiate() as Hud
	add_child(h)
	await wait_frames(3)
	assert_true(h.model == null, "nothing in G.LOCAL_HUD_MODEL, nothing bound")
	h.queue_free()


func test_demo_driver_runs_every_stage() -> void:
	var demo: Node = (load("res://content/ui/hud/mock/hud_demo.tscn") as PackedScene).instantiate()
	add_child(demo)
	await wait_frames(1)
	var driver: MockHudDriver = demo.get_node("Driver") as MockHudDriver
	for i: int in range(10):
		driver.t = float(i) * 4.0 + 0.1
		driver._process(0.0)
	var hud: Hud = demo.get_node("HudLayer/Hud") as Hud
	assert_true(await wait_until(func() -> bool: return hud.model is MockHudModel, 2.0),
			"demo HUD bound through the G.LOCAL_HUD_MODEL group")
	demo.queue_free()
	await wait_frames(1)
