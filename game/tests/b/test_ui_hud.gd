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


## ui_hud.md v1.2 (D-043 QA-22): custody widget bound to custody_changed / custody.
func test_custody_widget() -> void:
	var c: CustodyPanel = _hud.custody
	assert_false(c.visible, "no custody: hidden")
	_model.custody = {"in_custody": true, "negotiation_left_s": 25.0, "auto_release_left_s": 90.0, "highlighted_hostage_net_id": 0}
	assert_true(c.visible and c.title_label.visible)
	assert_eq(c.negotiation_label.text, UiText.t(&"ui.hud.custody_negotiation", {"seconds": UiText.clock(25.0)}))
	assert_true(c.release_label.visible)
	assert_eq(c.release_label.text, UiText.t(&"ui.hud.custody_release", {"seconds": UiText.clock(90.0)}))
	_model.custody = {"in_custody": true, "negotiation_left_s": 0.0, "auto_release_left_s": -1.0, "highlighted_hostage_net_id": 0}
	assert_eq(c.negotiation_label.text, UiText.t(&"ui.hud.custody_trade"), "trade possible now")
	assert_false(c.release_label.visible, "no auto release")
	_model.custody = {"in_custody": false, "negotiation_left_s": 0.0, "auto_release_left_s": -1.0, "highlighted_hostage_net_id": 42}
	assert_true(c.visible and c.hostage_label.visible, "free player: trade hint for the highlighted hostage")
	assert_false(c.title_label.visible)
	_model.custody = {}
	assert_false(c.visible)


## ui_hud.md v1.3 (D-049): captain widget bound to captain_changed / captain_present, captain_resistance.
func test_captain_widget() -> void:
	var c: CaptainPanel = _hud.captain
	assert_has(_hud.widgets(), c)
	assert_false(c.visible, "no captain: hidden")
	_model.captain_resistance = 0.25
	_model.captain_present = true
	assert_true(c.visible, "Brandt on the map")
	assert_near(c.resistance_bar.value, 0.25, 0.001)
	assert_eq(c.resistance_label.text, UiText.t(&"ui.hud.captain_resistance", {"pct": 25}))
	assert_false(c.resistance_label.text.contains("{"), "formatted")
	_model.captain_resistance = 0.5
	assert_near(c.resistance_bar.value, 0.5, 0.001)
	assert_eq(c.resistance_label.text, UiText.t(&"ui.hud.captain_resistance", {"pct": 50}))
	_model.warnings = [&"captain"]
	assert_false(_hud.status.warnings_label.visible, "the captain widget replaces the status warning line")
	_model.captain_present = false
	assert_false(c.visible, "retreated: hidden")
	# A model without the v1.3 fields (older LocalHudModel): widget hidden, status keeps the warning.
	var bare: Node = Node.new()
	bare.set_script(_warnings_only_script())
	add_child(bare)
	bare.set(&"warnings", [&"captain"] as Array[StringName])
	_hud.bind(bare)
	assert_false(c.visible)
	assert_eq(_hud.status.warnings_label.text, UiText.t(&"ui.hud.captain_warning"))
	_hud.bind(_model)
	bare.queue_free()


static func _warnings_only_script() -> GDScript:
	var gd: GDScript = GDScript.new()
	gd.source_code = "extends Node\nsignal warnings_changed()\nvar warnings: Array[StringName] = []\n"
	gd.reload()
	return gd


## ui_hud.md v1.4 (B4-19): stamina bar bound to stamina_changed / stamina, exhausted.
func test_stamina_widget() -> void:
	var w: StaminaBar = _hud.stamina
	assert_has(_hud.widgets(), w)
	assert_false(w.visible, "full stamina: hidden")
	_model.stamina = 0.4
	assert_true(w.visible, "draining: shown")
	assert_near(w.bar.value, 0.4)
	assert_eq(w.bar.self_modulate, _hud.stamina.tweak.stamina_color)
	assert_eq(w.label.text, UiText.t(&"ui.hud.stamina"))
	_model.stamina = 0.0
	_model.exhausted = true
	assert_true(w.visible)
	assert_eq(w.bar.self_modulate, w.tweak.stamina_exhausted_color, "exhausted tint")
	assert_eq(w.label.text, UiText.t(&"ui.hud.stamina_exhausted"))
	_model.stamina = 1.0
	assert_true(w.visible, "still exhausted at full: shown")
	_model.exhausted = false
	assert_false(w.visible, "recovered: hidden")
	assert_eq(w.bar.self_modulate, w.tweak.stamina_color)
	# A model without the v1.4 fields (ENV A before round 5): stays hidden, no errors.
	var bare: Node = Node.new()
	add_child(bare)
	w.bind(bare)
	assert_false(w.visible)
	bare.queue_free()


func test_vitals_and_downs() -> void:
	_model.max_health = 200.0
	_model.health = 50.0
	_model.downs_left = 1
	assert_near(_hud.vitals.health_bar.value, 0.25)
	assert_eq(_hud.vitals.health_label.text, "50")
	assert_eq(_hud.vitals.downs_label.text, UiText.t(&"ui.hud.downs_left", {"count": 1}))
	_model.bleedout_s = 12.2
	_model.crew_state = Enums.CrewState.DOWNED
	assert_false(_hud.vitals.state_label.visible, "downed: the centre overlay owns the bleedout")
	assert_true(_hud.downed.active and _hud.downed.timer_label.visible, "big bleedout timer when downed")
	assert_eq(_hud.downed.timer_label.text, UiText.t(&"ui.hud.bleedout_big", {"seconds": 13}))
	assert_eq(_hud.downed.revive_label.text, UiText.t(&"ui.hud.downed_hint"), "no revive yet")
	_model.revive_progress = 0.4  # ENV A extras (asked)
	_model.reviver_slot = 1
	assert_true(_hud.downed.revive_bar.visible)
	assert_near(_hud.downed.revive_bar.value, 0.4)
	_model.crew_state = Enums.CrewState.NORMAL
	assert_false(_hud.downed.active)


func test_interaction_prompt_and_blocked_reason() -> void:
	assert_false(_hud.interaction.visible, "hidden without a prompt")
	_model.interaction = {"text_key": &"ui.prompt.answer_pager", "args": {"key": "F"}, "progress": 0.4,
			"blocked_reason": &""}
	assert_true(_hud.interaction.visible)
	assert_eq(_hud.interaction.prompt.text, UiText.t(&"ui.prompt.answer_pager", {"key": "F"}))
	assert_near(_hud.interaction.progress_bar.value, 0.4)
	assert_false(_hud.interaction.blocked_label.visible)
	_model.interaction = {"text_key": &"ui.prompt.pick_lock", "args": {"key": "F"}, "progress": 0.0,
			"blocked_reason": &"ui.blocked.casing"}
	assert_eq(_hud.interaction.blocked_label.text, UiText.t(&"ui.blocked.casing", {"mask_key": InteractionPanel.action_key_text(&"mask_up")}),
			"PO-5.11: the casing block names the mask key")


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
	_model.objectives = [{"id": &"a", "text_key": &"objective.glasshouse.keycard", "args": {},
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
	var hud: Hud = demo.get_node("HudLayer/Hud") as Hud
	assert_true(await wait_until(func() -> bool: return hud.model is MockHudModel, 2.0),
			"demo HUD bound through the G.LOCAL_HUD_MODEL group")
	hud.bind(driver.model)  # this test's own MockHudModel is in the group too
	var captain_seen: bool = false
	var exhausted_seen: bool = false
	var drained: bool = false
	for i: int in range(10):
		driver.t = float(i) * 4.0 + 0.1
		driver._process(0.0)
		driver.t = float(i) * 4.0 + 2.0
		driver._process(0.0)
		captain_seen = captain_seen or driver.model.captain_present
		exhausted_seen = exhausted_seen or (driver.model.exhausted and hud.stamina.visible)
		drained = drained or (driver.model.stamina < 1.0 and not driver.model.exhausted)
	assert_true(captain_seen, "the timeline has a captain step")
	assert_true(drained and exhausted_seen, "the timeline drains stamina and shows exhausted")
	assert_false(driver.model.exhausted, "recovered by the fade")
	assert_false(driver.model.captain_present, "Brandt gone by the fade")
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
	assert_eq(_hud.interaction.prompt.text, UiText.t(&"ui.prompt.interact", {"key": key}))


## v1.6 civilian mode (S1.3, D-065): no gear widgets, a Civilian badge, teammates show their mode.
func test_civilian_mode_hides_gear_and_shows_the_badge() -> void:
	_model.player_mode = &"civilian"
	assert_false(_hud.ammo.visible, "no weapon / equipment widget without gear")
	assert_eq(_hud.status.mask_label.text, UiText.t(&"ui.hud.civilian"))
	_model.crew = [{"slot": 1, "name": "Sable", "is_ai": false, "health_frac": 1.0, "armor_frac": 1.0,
			"state": Enums.CrewState.NORMAL, "downs_left": 3, "carried_loot_id": &"", "mode": &"civilian"}]
	var info: Label = (_hud.teammates.list_box.get_child(0) as Control).find_children("*", "Label", true, false)[-1]
	assert_true(info.text.contains(UiText.t(&"ui.hud.civilian")), "teammate panel shows civilian")
	_model.player_mode = &"casing"  # gear picked up, no weapon out yet
	assert_false(_hud.ammo.visible, "PO-1: weapon HUD hidden while casing")
	assert_eq(_hud.status.mask_label.text, UiText.t(&"ui.hud.unmasked"))
	_model.player_mode = &"masked"
	assert_eq(_hud.status.mask_label.text, UiText.t(&"ui.hud.masked"))
	assert_true(_hud.ammo.visible, "weapon HUD once masked")
