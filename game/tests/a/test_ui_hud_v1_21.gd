## ui_hud v1.21 (D-163): LocalHudModel.perk_item = the deck throwable's state for any deck ({kind, charges, max,
## cooldown_left, active_left, partner_slot}) with perk_item_changed, from the replicated PerkItems; the pocket ECM
## shows there too (pocket_ecm stays one round as an alias), with its mode; v1.22 (D-164): segments while a Leech
## ampule runs.
extends TestCase

const GAS_ITEM: StringName = &"throwable.test_hud_gas"
const ECM_ITEM: StringName = &"throwable.test_hud_pocket_ecm2"

var _rt: HeistRuntime = null


func before_each() -> void:
	for pair: Array in [[GAS_ITEM, PerkTagTeam.KIND], [ECM_ITEM, PerkPocketEcm.KIND]]:
		var d: ThrowableDef = ThrowableDef.new()
		d.id = pair[0]
		d.kind = pair[1]
		d.count = 1
		ContentDB.inject(ContentDB.THROWABLES, d.id, d)
	_rt = await HeistLauncher.launch(&"unit_map", 1210, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "skip_casing": true})
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	ContentDB.clear_cache()
	await wait_frames(1)


func test_tag_team_item_on_the_hud_and_replicated() -> void:
	var hud: LocalHudModel = _rt.hud_model
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await wait_seconds(0.5)
	assert_eq(hud.perk_item, {}, "no deck item: {}")
	Modifiers.set_source(0, &"deck", {&"perk.tag_team": {"tag_range_m": 18.0, "duration_s": 11.0, "cooldown_s": 60.0},
		&"perk.throwable": {"item_id": GAS_ITEM}})
	var mate: CrewController = _rt.crew_controller(1) as CrewController
	mate.global_position = c.global_position + c.aim_direction().normalized() * 6.0
	await wait_seconds(0.5)
	assert_eq(StringName(hud.perk_item.get("kind", &"")), PerkTagTeam.KIND, "the gas dispenser, ready")
	assert_eq(int(hud.perk_item.get("charges", -1)), 1)
	var hits: Array[int] = [0]
	hud.perk_item_changed.connect(func() -> void: hits[0] += 1)
	assert_true(PerkHooks.use_throwable(c), "tagged")
	await wait_seconds(0.5)
	assert_eq(int(hud.perk_item.get("partner_slot", -1)), 1, "partner_slot on the HUD")
	assert_true(float(hud.perk_item.get("cooldown_left", 0.0)) > 50.0, "cooldown_left")
	assert_true(hits[0] >= 1, "perk_item_changed fired")
	var items: PerkItems = _rt.service(PerkItems.SERVICE) as PerkItems
	var mirror: PerkItems = PerkItems.new()
	mirror.apply_net_state(bytes_to_var(var_to_bytes(items.net_state())) as Dictionary)
	assert_eq(mirror.state(0), items.state(0), "replicated as is")
	mirror.free()
	Modifiers.clear_source(0, &"deck")
	await wait_seconds(0.5)
	assert_eq(hud.perk_item, {}, "the deck gone: {}")


func test_pocket_ecm_shows_as_perk_item() -> void:
	var hud: LocalHudModel = _rt.hud_model
	Modifiers.set_source(0, &"deck", {&"stealth.pocket_ecm": {"charges": 2, "duration_s": 6.0, "cooldown_s": 100.0},
		&"perk.throwable": {"item_id": ECM_ITEM}})
	PerkHooks.of(_rt.crew_controller(0) as CrewController).refresh()
	PerkHooks.use_throwable(_rt.crew_controller(0) as CrewController)
	await wait_seconds(0.5)
	assert_eq(StringName(hud.perk_item.get("kind", &"")), PerkPocketEcm.KIND, "kind pocket_ecm")
	assert_eq(int(hud.perk_item.get("charges", -1)), 1, "charges")
	assert_eq(int(hud.perk_item.get("max", -1)), 2, "max")
	assert_true(float(hud.perk_item.get("active_left", 0.0)) > 4.0, "active_left")
	assert_eq(int(hud.pocket_ecm.get("charges", -1)), 1, "the pocket_ecm alias still there")
	assert_eq(StringName(hud.perk_item.get("mode", &"x")), EcmSystem.MODE_JAM, "B's request: mode carried (jam)")


func test_v1_22_segments_replicate() -> void:
	var items: PerkItems = PerkItems.of(_rt)
	items.publish(0, PerkLeech.KEY, PerkItems.entry(PerkLeech.KIND, 0, 1, 0.0, 5.0, -1, &"", {"count": 3, "size": 10}))
	items.publish(1, PerkTagTeam.KEY, PerkItems.entry(PerkTagTeam.KIND, 1, 1, 0.0, 0.0))
	var mirror: PerkItems = PerkItems.new()
	mirror.apply_net_state(bytes_to_var(var_to_bytes(items.net_state())) as Dictionary)
	assert_eq(mirror.state(0).get("segments", {}), {"count": 3, "size": 10}, "segments while active")
	assert_false(mirror.state(1).has("segments"), "none for other kinds")
	assert_eq(StringName(mirror.state(1)["mode"]), &"", "mode empty for other kinds")
	mirror.free()
	await wait_seconds(0.5)
	assert_eq(_rt.hud_model.perk_item.get("segments", {}), {"count": 3, "size": 10}, "on the HUD")
