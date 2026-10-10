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


# --- ENV A's real LocalHudModel, bound directly (ui_hud.md v1.1; HudModelAdapter removed) ---------

func _real_model_class() -> Script:
	var cls: Script = UiNav.global_class(&"LocalHudModel")
	if cls == null:
		skip("LocalHudModel not in this tree")
	return cls


## Tiny HeistMap (floor + player spawns + Mission) built in code: no ENV C map needed.
static func _test_map() -> PackedScene:
	var root: HeistMap = HeistMap.new()
	root.name = "HudTestMap"
	var geo: Node3D = Node3D.new()
	geo.name = "Geometry"
	root.add_child(geo)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	floor_body.add_child(col)
	geo.add_child(floor_body)
	for nm: String in ["Props", "Lighting", "Zones", "Rooms", "Spawns", "Patrols", "Tactical", "Gameplay", "Variants", "ReviewCameras"]:
		var n: Node3D = Node3D.new()
		n.name = nm
		root.add_child(n)
	for i: int in range(4):
		var sp: SpawnPoint = SpawnPoint.new()
		sp.name = "Player%d" % i
		sp.kind = SpawnPoint.Kind.PLAYER
		sp.position = Vector3(-3 + 2 * i, 0.05, 5)
		root.get_node("Spawns").add_child(sp)
	var mission: Node = Node.new()
	mission.name = "Mission"
	mission.set_script(load("res://systems/heist/heist_mission.gd"))
	root.add_child(mission)
	for c: Node in root.get_children():
		_own(c, root)
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


static func _own(n: Node, root: Node) -> void:
	n.owner = root
	for c: Node in n.get_children():
		_own(c, root)


func test_real_model_binds_directly() -> void:
	var cls: Script = _real_model_class()
	if cls == null:
		return
	_model.remove_from_group(G.LOCAL_HUD_MODEL)
	var real: Node = cls.new() as Node
	add_child(real)
	real.set_process(false)
	var h: Hud = HUD_SCENE.instantiate() as Hud
	add_child(h)
	assert_true(await wait_until(func() -> bool: return h.model == real, 2.0), "HUD finds the real model via the group")
	for w: HudWidget in h.widgets():
		assert_eq(w.model, real, "%s bound directly (no adapter)" % w.name)
	assert_false(h.has_node("HudModelAdapter"), "no adapter node")
	real.call(&"refresh")  # no HeistRuntime: stub vitals from Tweak
	assert_eq(h.vitals.health_label.text, str(roundi(float(real.get(&"health")))), "vitals from the real model")
	# Pagers: no pager service here, so the model's EventBus fallback drives them (event).
	EventBus.pager_started.emit(9101, 0)
	var pagers: Array = real.get(&"pagers") as Array
	assert_eq(pagers.size(), 1, "pager row from pager_started")
	assert_eq(h.pager.pager_labels[0].text, UiText.t(&"ui.hud.pager",
			{"seconds": UiText.clock(float((pagers[0] as Dictionary)["time_left_s"]))}), "pager panel follows pagers_changed")
	EventBus.pager_answered.emit(9101, 0, 1)
	assert_eq((real.get(&"pagers") as Array).size(), 0)
	var left: int = int(real.get(&"pagers_max")) - 1
	assert_eq(h.pager.pagers_left_label.text, UiText.t(&"ui.hud.pagers_left", {"count": left}), "pagers left")
	h.queue_free()
	real.queue_free()
	await wait_frames(1)


func test_real_model_in_heist_drives_vitals_ammo_warnings() -> void:
	if _real_model_class() == null:
		return
	_model.remove_from_group(G.LOCAL_HUD_MODEL)
	var launcher: Script = UiNav.global_class(&"HeistLauncher")
	var rt: Node = await launcher.call(&"launch", &"hud_test_map", 4242, Enums.Difficulty.ROUTINE, self,
			{"map_packed": _test_map(), "ai_teammates": 0})
	assert_true(rt != null, "runtime launched")
	if rt == null:
		return
	var real: Node = get_tree().get_first_node_in_group(G.LOCAL_HUD_MODEL)
	assert_true(real != null and real.get_script() == UiNav.global_class(&"LocalHudModel"), "real model in the group")
	var h: Hud = HUD_SCENE.instantiate() as Hud
	add_child(h)
	assert_true(await wait_until(func() -> bool: return h.model == real, 2.0), "in-heist HUD binds through the group")
	var crew: Node = rt.call(&"crew_controller", Net.local_slot()) as Node
	assert_true(crew != null, "local crew member")
	# Vitals: a hit through the single hit path, then the model's poll.
	real.call(&"refresh")
	var hp0: float = float(real.get(&"health"))
	var ar0: float = float(real.get(&"armor"))
	crew.call(&"take_hit", Damage.info(30.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", Vector3.ZERO,
			Vector3.FORWARD, 0), 0)
	real.call(&"refresh")
	var hp1: float = float(real.get(&"health"))
	var ar1: float = float(real.get(&"armor"))
	assert_true(hp1 < hp0 or ar1 < ar0, "the hit reached the model's vitals")
	assert_eq(h.vitals.health_label.text, str(roundi(hp1)), "health label")
	assert_eq(h.vitals.armor_label.text, str(roundi(ar1)), "armor label")
	# Ammo: CrewWeapons.set_ammo (server/test hook), then the poll.
	var w: Object = crew.get(&"weapons") as Object
	var ws: int = int(w.get(&"equipped_slot"))
	w.call(&"set_ammo", ws, 3, 21)
	real.call(&"refresh")
	assert_eq(int(real.get(&"equipped_slot")), ws)
	assert_eq(h.ammo.ammo_label.text, UiText.t(&"ui.hud.ammo", {"mag": 3, "reserve": 21}), "ammo label")
	# Warnings: TASED raises the stinger warning (poll).
	crew.call(&"set_crew_state", Enums.CrewState.TASED)
	real.call(&"refresh")
	assert_has(real.get(&"warnings") as Array, &"stinger")
	assert_true(h.status.warnings_label.visible, "warning shown")
	assert_eq(h.status.warnings_label.text, UiText.t(&"ui.hud.stinger_warning"))
	crew.call(&"set_crew_state", Enums.CrewState.NORMAL)
	real.call(&"refresh")
	assert_false(h.status.warnings_label.visible, "warning cleared")
	# Masked/casing (S1.1).
	assert_eq(h.status.mask_label.text, UiText.t(&"ui.hud.unmasked"), "starts casing")
	crew.call(&"set_masked", false)
	real.call(&"refresh")
	assert_eq(h.status.mask_label.text, UiText.t(&"ui.hud.masked"))
	h.queue_free()
	rt.call(&"teardown")
	await wait_frames(2)


func test_marked_targets_drawn_in_front_only() -> void:
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.current = true
	_model.marked_targets = [
		{"net_id": 11, "world_pos": Vector3(0, -2.1, -10), "kind": &"guard"},
		{"net_id": 12, "world_pos": Vector3(0, 0, 10), "kind": &"camera"},
	]
	var m: Array[Dictionary] = _hud.marks.markers
	assert_eq(m.size(), 1, "the target behind the camera is not drawn")
	assert_eq(int(m[0]["net_id"]), 11)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	assert_near((m[0]["screen_pos"] as Vector2).x, vp.x * 0.5, 1.0, "straight ahead = screen centre")
	_model.marked_targets = []
	assert_eq(_hud.marks.markers.size(), 0)
	cam.queue_free()


func test_interaction_key_filled_when_model_has_none() -> void:
	_model.interaction = {"text_key": &"ui.prompt.interact", "args": {}, "progress": 0.0, "blocked_reason": &""}
	var key: String = InteractionPanel.action_key_text(&"interact")
	assert_ne(key, "", "interact is bound in the InputMap")
	assert_eq(_hud.interaction.prompt_label.text, UiText.t(&"ui.prompt.interact", {"key": key}))
