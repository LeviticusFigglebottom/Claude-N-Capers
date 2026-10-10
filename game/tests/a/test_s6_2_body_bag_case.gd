## A2-06 / S6.2: the body bag case deployable holds 3 body bags; interacting takes one up to the
## inventory cap (2, stealth.body_bags_extra raises it).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _launch() -> void:
	var l: Loadout = Loadout.new()
	l.deployable = &"deployable.body_bag_case"
	_rt = await HeistLauncher.launch(&"unit_map", 62, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "skip_casing": true, "loadouts": {0: l}})


func _place() -> DeployablePrefab:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await wait_physics_frames(3)
	var sys: DeployableSystem = _rt.service(DeployableSystem.SERVICE) as DeployableSystem
	var p: DeployablePrefab = sys.place(c) as DeployablePrefab
	await wait_physics_frames(2)
	return p


func _take(p: Node) -> void:
	ATestMaps.hold_interact(_rt, 0, NetIds.of(p))
	await wait_seconds(DeployableTweak.data().use_time_s[&"body_bag_case"] + 0.3)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)


func test_s6_2_case_holds_3_and_respects_cap() -> void:
	await _launch()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var p: DeployablePrefab = await _place()
	assert_true(p != null, "case placed")
	assert_eq(p.kind, &"body_bag_case")
	assert_eq(p.uses_left, 3, "holds 3 body bags")
	assert_eq(p.interactable.kind, &"take_body_bag")
	assert_eq(c.body_bags, Tweak.crew().body_bags_base, "starts with the base bag")
	await _take(p)
	assert_eq(c.body_bags, 2, "took one")
	assert_eq(p.uses_left, 2)
	assert_ne(p.interactable.availability(c), InteractableComponent.BLOCK_NONE, "at the cap of 2")
	await _take(p)
	assert_eq(c.body_bags, 2, "cap respected")
	assert_eq(p.uses_left, 2, "nothing taken at the cap")
	c.body_bags = 0
	await _take(p)
	await _take(p)
	assert_eq(c.body_bags, 2, "two more taken")
	assert_true(not is_instance_valid(p) or p.is_queued_for_deletion(), "empty case removed")


func test_s6_2_body_bags_extra_raises_cap() -> void:
	Modifiers.set_source(0, &"test", {&"stealth.body_bags_extra": 1})
	await _launch()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var p: DeployablePrefab = await _place()
	var start: int = c.body_bags
	assert_eq(DeployablePrefab.body_bag_cap(0), 3, "cap 3 with +1")
	await _take(p)
	assert_eq(c.body_bags, mini(start + 1, 3), "took up to the raised cap")
