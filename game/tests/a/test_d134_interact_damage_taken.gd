## Hold the Line ACED (B): defense.interact_damage_taken_mult scales incoming damage while the crew member holds an
## interaction (D-134: damage never cancels a hold, so this is the skill's point). No hold, or no modifier: unchanged.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	Modifiers.clear_source(0, &"test.htl")
	if _rt != null and is_instance_valid(_rt):
		_rt.interaction._sessions.erase(0)
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _hit(c: CrewController) -> float:
	var before: float = c.health.health + c.health.armor
	c.health.invuln_left = 0.0
	c.health.grace_left = 0.0  # D-145 hit grace: back-to-back hits here test the hold multiplier
	c.health.take_hit(Damage.info(10.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", c.global_position,
		Vector3.FORWARD, 0))
	return before - (c.health.health + c.health.armor)


func test_interact_damage_taken_mult_applies_only_while_holding() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1341, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	assert_near(_hit(c), 10.0, 0.01, "no modifier, no hold: full damage")
	Modifiers.set_source(0, &"test.htl", {&"defense.interact_damage_taken_mult": 0.5})
	assert_near(_hit(c), 10.0, 0.01, "modifier but no hold: full damage")
	var comp: InteractableComponent = InteractableComponent.new()
	_rt.interaction._sessions[0] = {"comp": comp, "crew": c, "progress": 0.2, "duration": 5.0,
		"start_pos": c.global_position, "aimed": true, "owner_id": 0}
	assert_near(_hit(c), 5.0, 0.01, "holding an interaction: x0.5")
	_rt.interaction._sessions.erase(0)
	comp.free()
