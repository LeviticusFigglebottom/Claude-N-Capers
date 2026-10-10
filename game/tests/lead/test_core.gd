## Lead-owned tests for core autoloads and contracts.
extends TestCase


func test_rng_streams_are_independent_and_deterministic() -> void:
	GameRng.begin_run(1234)
	var a1: int = GameRng.stream(&"patrols").randi()
	var b1: int = GameRng.stream(&"cameras").randi()
	GameRng.begin_run(1234)
	# Rolling a different stream first must not change patrol results.
	var b2: int = GameRng.stream(&"cameras").randi()
	var a2: int = GameRng.stream(&"patrols").randi()
	assert_eq(a1, a2, "patrol stream deterministic")
	assert_eq(b1, b2, "camera stream deterministic")
	assert_ne(a1, b1, "streams differ")


func test_modifiers_aggregate() -> void:
	Modifiers.clear_all()
	Modifiers.set_source(0, &"skills", {&"stealth.body_bags_extra": 2, &"weapon.damage_mult.shotgun": 1.5})
	Modifiers.set_source(0, &"perk", {&"weapon.damage_mult.all": 1.1})
	Modifiers.set_source(Modifiers.TEAM, &"asset.body_bag_case", {&"stealth.body_bags_extra": 2})
	assert_near(Modifiers.add(0, &"stealth.body_bags_extra"), 4.0)
	assert_near(Modifiers.add(1, &"stealth.body_bags_extra"), 2.0, 0.0001, "team source applies to slot 1")
	assert_near(Modifiers.mult(0, &"weapon.damage_mult", &"shotgun"), 1.65)
	assert_near(Modifiers.mult(0, &"weapon.damage_mult", &"pistol"), 1.1)
	assert_false(Modifiers.flag(0, &"stealth.silent_devices"))
	Modifiers.clear_all()


func test_modifier_registry_known_keys() -> void:
	assert_true(ModifierKeys.is_known(&"weapon.damage_mult.shotgun"))
	assert_true(ModifierKeys.is_known(&"stealth.ecm_feedback"))
	assert_false(ModifierKeys.is_known(&"stealth.made_up_key"))


func test_solo_session_is_authority_with_ai_crew() -> void:
	Net.start_solo("Tester", 3)
	assert_true(Net.is_authority(), "solo is authority")
	assert_eq(Net.all_slots().size(), 4)
	assert_eq(Net.human_slots().size(), 1)
	assert_eq(Net.local_slot(), 0)


func test_crew_intent_roundtrip() -> void:
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0.5, 1.0)
	i.interact = true
	i.order = &"hold"
	var j: CrewIntent = CrewIntent.from_dict(i.to_dict())
	assert_eq(j.move, i.move)
	assert_true(j.interact)
	assert_eq(j.order, &"hold")
