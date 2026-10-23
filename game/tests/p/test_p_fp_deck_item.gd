## LEAD r298: the first-person perk-deck item use pose (FpViewmodelDeck on A's CrewThrowables.deck_item_used).
## Real input for the leech ampule (G with the deck's perk.throwable); every deck kind through the server hook:
## the item in the hand and the gun hidden, the kind's arm pose and part motion, the gun drawn again in about 1 s.
extends TestCase

const ITEMS: Dictionary = {
	&"throwable.boss_injector": &"injector", &"throwable.leech_ampule": &"leech_ampule",
	&"throwable.steady_flask": &"flask", &"throwable.pocket_ecm": &"pocket_ecm",
	&"throwable.gas_dispenser": &"gas_dispenser", &"throwable.smoke_bomb": &"smoke_bomb",
}
const LEECH: Dictionary = {"duration_s": 6.0, "cooldown_s": 40.0, "kill_cooldown_reduction_s": 1.0,
	"activate_heal_fraction": 0.4, "armor_off": true, "segment_fraction": 0.2, "kills_per_segment": 2,
	"team_heal_on_damage_fraction": 0.05}

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 2980, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "skip_casing": true})
	_inp = PInputDriver.new(self)
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await wait_seconds(1.0)


func after_each() -> void:
	if _inp != null:
		_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _vm() -> FpViewmodel:
	return FpViewmodel.of(CrewView.of(_crew()).camera())


func _part(vm: FpViewmodel, part: String) -> Node3D:
	return vm._item.find_child(part, true, false) as Node3D if vm._item != null and is_instance_valid(vm._item) else null


## Seconds into the hold of `kind` (after the draw).
func _mid_hold(kind: StringName) -> float:
	return FpViewmodelDeck.DRAW_S + float(FpViewmodelDeck.POSES[kind]["hold_s"]) * 0.6


## Wait until the viewmodel's sequence clock reaches `t` (the pose runs on it; wall time drifts under load).
func _at(vm: FpViewmodel, t: float) -> void:
	await wait_until(func() -> bool: return vm.action != FpViewmodel.Action.DECK or vm._seq_t >= t, 5.0)


## The gun is back (its draw or idle) and the item gone, within `limit_s`.
func _gun_back(vm: FpViewmodel, limit_s: float) -> void:
	var back: bool = await wait_until(func() -> bool: return vm.action != FpViewmodel.Action.DECK, limit_s)
	assert_true(back, "the use pose ends within %.1f s" % limit_s)
	assert_true(vm._item == null, "the item leaves the hand")
	assert_true(vm.weapon_visual != null and vm.weapon_visual.visible, "the gun is back in the hands")


func test_leech_ampule_real_input() -> void:
	Modifiers.set_source(0, &"deck", {PerkLeech.KEY: LEECH, &"perk.throwable": {"item_id": &"throwable.leech_ampule"}})
	PerkHooks.of(_crew()).refresh()
	var vm: FpViewmodel = _vm()
	assert_true(vm != null, "an FP viewmodel")
	await _inp.tap(&"throw_item")
	await wait_frames(2)
	assert_eq(vm.action, FpViewmodel.Action.DECK, "G plays the deck item's use pose")
	assert_eq(vm.deck.kind, &"leech_ampule", "the ampule")
	assert_false(vm.weapon_visual.visible, "the gun is put away")
	var serum: Node3D = _part(vm, "Serum")
	assert_true(serum != null, "the ampule (Serum) in the hand")
	await _at(vm, _mid_hold(&"leech_ampule"))
	assert_true(vm.deck.offset.y < -0.05, "pressed down to the thigh (offset %s)" % vm.deck.offset)
	await _at(vm, _mid_hold(&"leech_ampule") + 0.08)
	assert_true(serum.scale.y < 0.9, "the serum drains (%.2f)" % serum.scale.y)
	await _gun_back(vm, 1.0)


func test_every_kind_pose() -> void:
	for id: StringName in ITEMS:
		await _kind(id, ITEMS[id])


func _kind(id: StringName, kind: StringName) -> void:
	var vm: FpViewmodel = _vm()
	await wait_until(func() -> bool: return vm.action == FpViewmodel.Action.NONE, 3.0)
	CrewThrowables.deck_item_fired(_crew(), id, kind)
	await wait_frames(2)
	assert_eq(vm.action, FpViewmodel.Action.DECK, "%s: the use pose plays" % kind)
	assert_true(vm._item != null and not vm.weapon_visual.visible, "%s: the item replaces the gun" % kind)
	if kind == &"smoke_bomb":
		await _at(vm, CombatTweak.data().throw_windup_s + 0.02)
		var pin: Node3D = _part(vm, "Pin")
		assert_true(pin == null or not pin.visible, "smoke: the pin is pulled")
		assert_true(vm._item == null or not vm._item.visible, "smoke: thrown at the release")
		await _gun_back(vm, 1.0)
		return
	var rest_can: float = _part(vm, "Canister").position.y if _part(vm, "Canister") != null else 0.0
	var blinked: bool = false
	await _at(vm, FpViewmodelDeck.DRAW_S + float(FpViewmodelDeck.POSES[kind]["hold_s"]) * 0.35)
	while vm.action == FpViewmodel.Action.DECK and vm._seq_t < _mid_hold(kind):
		var led: Node3D = _part(vm, "Led")
		blinked = blinked or (led != null and not led.visible)
		await wait_frames(1)
	var pose: Vector3 = FpViewmodelDeck.POSES[kind]["rot"]
	assert_true(vm.deck.rot_deg.length() > pose.length() * 0.5, "%s: the arm pose (%s)" % [kind, vm.deck.rot_deg])
	match kind:
		&"injector", &"flask":
			assert_false(_part(vm, "Pin").visible, "%s: the cap is off" % kind)
		&"gas_dispenser":
			assert_true(_part(vm, "Canister").position.y < rest_can - 0.004, "gas: the canister is pressed")
		&"pocket_ecm":
			assert_true(blinked, "ecm: the LED blinks after the thumb press")
	if kind == &"flask":
		assert_true(vm.deck.rot_deg.x > 0.0, "flask: tipped up to the mouth")
	elif kind == &"injector" or kind == &"leech_ampule":
		assert_true(vm.deck.offset.y < 0.0, "%s: down to the thigh" % kind)
	await _gun_back(vm, 1.2)
