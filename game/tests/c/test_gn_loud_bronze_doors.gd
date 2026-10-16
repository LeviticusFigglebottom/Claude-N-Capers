## P's GN loud rerun (env/p-play 05d7cffa): after last call the bronze doors are locked LOCKPICK, and loud links
## them for the police, so crew paths ran into a shut leaf. On the alarm the mission unlocks and breaches them open.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_bronze_doors_open_on_loud_after_last_call() -> void:
	_rt = await HeistLauncher.launch(&"gallery_night", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched gallery_night")
	await wait_physics_frames(3)
	var doors: Array[Door] = []
	for p: String in ["Gameplay/Doors/BronzeDoorsW", "Gameplay/Doors/BronzeDoorsE"]:
		doors.append(_rt.map.get_node(p) as Door)
	_rt.mission.call(&"_on_last_call")
	await wait_physics_frames(2)
	for d: Door in doors:
		assert_true(d.locked and not d.is_open, "%s shut and locked after last call" % d.name)
	EventBus.alarm_raised.emit(&"test", 0)
	await wait_physics_frames(3)
	for d: Door in doors:
		assert_true(d.is_open and not d.locked, "%s open and unlocked once loud" % d.name)
