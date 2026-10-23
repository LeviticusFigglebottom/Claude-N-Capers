## ui_hud v1.20 (D-161, round 290): LocalHudModel.pocket_ecm = EcmSystem.pocket_state(tracked slot) with
## pocket_ecm_changed, and throwable_id from PerkHooks.throwable_id (a deck throwable replaces the loadout's).
extends TestCase

const ITEM: StringName = &"throwable.test_hud_pocket_ecm"

var _rt: HeistRuntime = null


func before_each() -> void:
	var d: ThrowableDef = ThrowableDef.new()
	d.id = ITEM
	d.kind = PerkPocketEcm.KIND
	d.count = 1
	ContentDB.inject(ContentDB.THROWABLES, ITEM, d)
	_rt = await HeistLauncher.launch(&"unit_map", 1200, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "skip_casing": true})
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	ContentDB.clear_cache()
	await wait_frames(1)


func test_pocket_ecm_and_deck_throwable_on_the_hud() -> void:
	var hud: LocalHudModel = _rt.hud_model
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await wait_seconds(0.5)
	assert_eq(hud.pocket_ecm, {}, "no pocket ECM: {}")
	var loadout_item: StringName = hud.throwable_id
	Modifiers.set_source(0, &"deck", {&"stealth.pocket_ecm": {"charges": 2, "duration_s": 6.0, "cooldown_s": 100.0},
		&"perk.throwable": {"item_id": ITEM}})
	await wait_seconds(0.5)
	assert_eq(hud.throwable_id, ITEM, "the deck throwable replaces the loadout's (%s)" % loadout_item)
	var hits: Array[int] = [0]
	hud.pocket_ecm_changed.connect(func() -> void: hits[0] += 1)
	assert_true(PerkHooks.use_throwable(c), "used")
	await wait_seconds(0.5)
	assert_eq(int(hud.pocket_ecm.get("charges", -1)), 1, "charges on the HUD")
	assert_eq(StringName(hud.pocket_ecm.get("mode", &"")), EcmSystem.MODE_JAM, "mode on the HUD")
	assert_true(hits[0] >= 1, "pocket_ecm_changed fired")
	Modifiers.clear_source(0, &"deck")
	await wait_seconds(0.5)
	assert_eq(hud.throwable_id, loadout_item, "deck gone: the loadout's throwable again")
