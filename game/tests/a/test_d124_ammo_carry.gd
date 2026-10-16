## D-124 (B's weapon balance audit): ammo boxes give whole rounds with the fraction carried over per crew member
## and weapon, so a weapon whose box is worth less than a round (Thumper 0.2-0.4, bows 0.5-1) gets the data's
## expected amount instead of a floor of 1 per box. The carry resets when the weapon fills up.
extends TestCase

const BOXES: int = 20

var _rt: HeistRuntime = null


func after_each() -> void:
	Modifiers.clear_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> CrewController:
	_rt = await HeistLauncher.launch(&"unit_map", 1240, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	return c


func _ammo() -> AmmoPickupSystem:
	return _rt.service(AmmoPickupSystem.SERVICE) as AmmoPickupSystem


## Walk over `n` boxes one at a time; returns the rounds weapon slot `ws` gained.
func _walk_over(c: CrewController, ws: int, n: int) -> int:
	var before: int = c.weapons.reserve(ws)
	for i: int in n:
		_ammo().drop(c.global_position + Vector3(0.2, 0.05, 0.0))
		await wait_physics_frames(2)
		assert_eq(_ammo().boxes().size(), 0, "box %d taken (a fraction still counts)" % i)
	return c.weapons.reserve(ws) - before


func test_fractional_boxes_add_up_to_the_data() -> void:
	var c: CrewController = await _launch()
	var ws: int = Enums.WeaponSlot.SECONDARY
	var st: WeaponStats = c.weapons.stats(ws)
	assert_true(st != null and st.ammo_pickup_max > 0.0, "the sidearm has pickup values")
	# Scale one box to ~0.3 of a round, a Thumper-sized pickup.
	var m: float = 0.3 / st.ammo_pickup_max
	Modifiers.set_source(0, &"t", {&"weapon.ammo_pickup_mult.all": m})
	c.weapons.set_ammo(Enums.WeaponSlot.PRIMARY, c.weapons.mag(Enums.WeaponSlot.PRIMARY),
		DeployablePrefab.max_ammo(c, Enums.WeaponSlot.PRIMARY))  # primary full: only the sidearm picks up
	c.weapons.set_ammo(ws, c.weapons.mag(ws), 0)
	var got: int = await _walk_over(c, ws, BOXES)
	var lo: float = minf(st.ammo_pickup_min, st.ammo_pickup_max) * m * BOXES
	var hi: float = st.ammo_pickup_max * m * BOXES
	assert_true(got >= floori(lo) - 1 and got <= ceili(hi),
		"%d boxes of %.2f-%.2f rounds give %d (not %d, one each)" % [BOXES, lo / BOXES, hi / BOXES, got, BOXES])
	var carry: float = _ammo().carry(c, ws)
	assert_true(carry >= 0.0 and carry < 1.0, "the leftover fraction carries over (%.3f)" % carry)


func test_whole_boxes_unchanged_and_carry_resets_when_full() -> void:
	var c: CrewController = await _launch()
	var ws: int = Enums.WeaponSlot.SECONDARY
	var st: WeaponStats = c.weapons.stats(ws)
	c.weapons.set_ammo(Enums.WeaponSlot.PRIMARY, c.weapons.mag(Enums.WeaponSlot.PRIMARY),
		DeployablePrefab.max_ammo(c, Enums.WeaponSlot.PRIMARY))
	c.weapons.set_ammo(ws, c.weapons.mag(ws), 0)
	var got: int = await _walk_over(c, ws, 1)
	assert_true(got >= floori(minf(st.ammo_pickup_min, st.ammo_pickup_max)) and got <= ceili(st.ammo_pickup_max),
		"a normal box gives its whole rounds (%d)" % got)
	var room: int = DeployablePrefab.max_ammo(c, ws) - c.weapons.mag(ws)
	c.weapons.set_ammo(ws, c.weapons.mag(ws), room - 1)  # one round short: the box is capped
	await _walk_over(c, ws, 1)
	assert_eq(c.weapons.reserve(ws), room, "filled to the cap")
	assert_eq(_ammo().carry(c, ws), 0.0, "a full weapon carries nothing over")
