## PO6-20: a live pager's answer prompt is aimable from anywhere around the body (aim_radius_m), sits on
## the body where it lies, and the HUD pager row carries guard_net_id + world_pos.
extends TestCase

const GUARD_POS: Vector3 = Vector3(5, 0.05, -5)

var _rt: HeistRuntime = null
var _started: Array[int] = []


func before_each() -> void:
	_started.clear()
	_rt = await HeistLauncher.launch(&"unit_po6_20", 620, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "skip_casing": true})
	EventBus.pager_started.connect(_on_started)


func after_each() -> void:
	EventBus.pager_started.disconnect(_on_started)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _on_started(pid: int, _guard: int) -> void:
	_started.append(pid)


func _aim(c: CrewController, at: Vector3) -> void:
	var to: Vector3 = at - c.eye_position()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-to.x, -to.z)
	i.look_pitch = atan2(to.y, Vector2(to.x, to.z).length())
	_rt.set_bot_intent(0, i)


func test_po6_20_answer_prompt_all_around_the_body() -> void:
	var g: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, g.global_position + Vector3(1.4, 0, 0.6)))
	await wait_physics_frames(2)
	g.die({}, c.net_id)
	var ok: bool = await wait_until(func() -> bool: return not _started.is_empty(), 6.0)
	assert_true(ok, "pager beeps")
	if not ok:
		return
	var comp: InteractableComponent = g.get_node_or_null(PagerSystem.COMP_NAME) as InteractableComponent
	assert_true(comp != null, "pager interactable on the body")
	assert_true(comp.aim_radius_m >= 0.5, "aim radius set")
	# Aim 0.8 m to the side of the prompt point (across the line of sight): still the pager prompt.
	_aim(c, comp.global_position + Vector3(0.0, -0.1, -0.8))
	await wait_physics_frames(2)
	assert_true(_rt.interaction.aimed_component(c) == comp, "aiming 0.8 m off the prompt point still answers")
	# Far off the body: nothing.
	_aim(c, comp.global_position + Vector3(0.0, 2.5, -3.0))
	await wait_physics_frames(2)
	assert_false(_rt.interaction.aimed_component(c) == comp, "aiming well away from the body does not")
	var hud: LocalHudModel = LocalHudModel.new()
	_rt.add_child(hud)
	hud.refresh()
	assert_eq(hud.pagers.size(), 1, "one pager row")
	if hud.pagers.size() == 1:
		var row: Dictionary = hud.pagers[0]
		assert_eq(int(row.get("guard_net_id", 0)), g.net_id, "row has guard_net_id")
		var wp: Vector3 = row.get("world_pos", Vector3.ZERO)
		assert_true(wp.distance_to(comp.global_position) < 1.5 and wp.y > g.global_position.y + 0.9,
			"row world_pos above the body (%s)" % wp)
	hud.queue_free()
