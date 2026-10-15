## PO6-05 follow-up (lead, P's D-111 coverage run): a player standing at the content's UsePoint of an OPEN safe
## can aim at and take EVERY item in it, one hold at a time, on all five heists (Golden Hour's 4 jewelry bags
## included). Real input path: aim (look yaw/pitch) + hold interact through InteractionSystem; each bag taken is
## dropped behind the player before the next hold.
extends TestCase

const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"dockside_burn", &"shadow_ledger", &"gallery_night"]
const FORCE: Dictionary = {&"night_deposit": {&"extra_loot": [&"mgr_safe_full"]}}

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


static func _left(o: Variant) -> int:
	if not is_instance_valid(o):
		return 0  # small loot frees itself once taken
	var p: GameplayPrefab = o as GameplayPrefab
	if &"remaining" in p:
		return int(p.get(&"remaining"))
	return 0 if p.get(&"taken") == true else 1


## Stand at the UsePoint, aim, hold until one item is taken (or 15 s); release; drop a carried bag. True if taken.
func _take_one(safe: Safe, p: GameplayPrefab) -> bool:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var up: Marker3D = p.use_point if p.use_point != null else safe.use_point
	_rt.teleport_crew(0, up.global_transform.translated(Vector3(0, 0.05, 0)))
	await wait_physics_frames(2)
	var d: Vector3 = p.interactable.global_position - c.eye_position()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-d.x, -d.z)
	i.look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(2)
	if _rt.interaction.aimed_component(c) != p.interactable:
		_rt.clear_bot_intent(0)
		return false
	var before: int = _left(p)
	i.interact = true
	var po: Object = p
	var ok: bool = await wait_until(func() -> bool: return _left(po) < before or c.is_carrying_bag(), 15.0)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)
	_rt.clear_bot_intent(0)
	if c.is_carrying_bag():
		var bag: LootBag = (_rt.service(G.SVC_LOOT) as LootManager).drop_bag(c, false)
		if bag != null:
			bag.global_position = up.global_position + Vector3(0, 0.3, 0) + up.global_basis.z * 2.5
	await wait_physics_frames(2)
	return ok


func test_po6_05_player_bags_every_safe_item_from_the_use_point() -> void:
	var total: int = 0
	for heist: StringName in HEISTS:
		var opts: Dictionary = {"crew_ai": false, "skip_casing": true}
		if FORCE.has(heist):
			opts["preplan"] = {"version": 1, "force_variants": FORCE[heist]}
		_rt = await HeistLauncher.launch(heist, 7, Enums.Difficulty.ROUTINE, self, opts)
		(_rt.crew_controller(0) as CrewController).set_masked()
		await wait_physics_frames(5)
		for n: Node in _rt.find_children("*", "Safe", true, false):
			var safe: Safe = n as Safe
			if safe.contents().is_empty():
				continue
			safe.swing_open()
			await wait_physics_frames(2)
			for p: GameplayPrefab in safe.contents():
				var tag: String = "%s/%s/%s" % [heist, safe.name, p.name]
				var guard: int = 0
				while is_instance_valid(p) and _left(p) > 0 and guard < 8:
					guard += 1
					var ok: bool = await _take_one(safe, p)
					assert_true(ok, "%s: item %d taken from the UsePoint (left %d)" % [tag, guard, _left(p)])
					if not ok:
						break
					total += 1
				var po: Object = p
				assert_eq(_left(po), 0, "%s: emptied" % tag)
		_rt.teardown()
		_rt = null
		await wait_frames(1)
	assert_true(total >= 8, "took %d safe items across the heists" % total)
