## PP audit (headless): real maps (Glasshouse, Night Deposit). Interact reach from each prompt's UsePoint with
## aimed resolution (what a player gets), door widths for followers. Prints AUDIT lines; asserts nothing yet.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _aim(c: CrewController, at: Vector3) -> CrewIntent:
	var d: Vector3 = at - c.eye_position()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-d.x, -d.z)
	i.look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	return i


func _audit_reach(heist: StringName) -> void:
	_rt = await HeistLauncher.launch(heist, 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched %s" % heist)
	await wait_physics_frames(5)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var total: int = 0
	var bad: int = 0
	for n: Node in get_tree().get_nodes_in_group(G.INTERACTABLE):
		var comp: InteractableComponent = n as InteractableComponent
		if comp == null or not _rt.is_ancestor_of(comp) or not comp.enabled:
			continue
		var owner: Node = comp.owner_node()
		var p: GameplayPrefab = owner as GameplayPrefab
		if p == null or p.use_point == null:
			continue
		total += 1
		_rt.teleport_crew(0, p.use_point.global_transform)
		await wait_physics_frames(1)
		_rt.set_bot_intent(0, _aim(c, comp.global_position))
		await wait_physics_frames(2)
		var got: InteractableComponent = _rt.interaction.aimed_component(c)
		if got != comp:
			bad += 1
			var d: float = c.eye_position().distance_to(comp.global_position)
			print("AUDIT %s reach FAIL %s kind=%s eye_dist=%.2f got=%s" % [heist, p.get_path(), comp.kind, d,
				str(got.owner_node().name) if got != null else "null"])
	print("AUDIT %s reach %d/%d prompts reachable from their UsePoint" % [heist, total - bad, total])
	for d: Node in get_tree().get_nodes_in_group(Door.GROUP):
		var door: Door = d as Door
		if door != null and _rt.is_ancestor_of(door) and door.effective_width() < 0.95:
			print("AUDIT %s door %s width %.2f" % [heist, door.name, door.effective_width()])


func test_pp_audit_reach_glasshouse() -> void:
	await _audit_reach(&"glasshouse")


func test_pp_audit_reach_night_deposit() -> void:
	await _audit_reach(&"night_deposit")
