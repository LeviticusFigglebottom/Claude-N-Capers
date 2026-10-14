## Roster wiring (lead round 186, Marten): every playable heister has both a third-person body
## (CrewTweak.body_scenes) and first-person sleeves (FpViewmodelTweak.sleeve_scenes), and a teammate playing
## each one spawns that body, animated. Owner: ENV P.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _loadout(heister: StringName) -> Loadout:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.heister = heister
	return l


func test_bodies_and_sleeves_match() -> void:
	var bodies: Dictionary[StringName, PackedScene] = Tweak.crew().body_scenes
	var sleeves: Dictionary[StringName, PackedScene] = FpViewmodelTweak.data().sleeve_scenes
	assert_true(bodies.has(&"marten") and sleeves.has(&"marten"), "Marten wired (body + sleeves)")
	for h: StringName in bodies:
		assert_true(sleeves.has(h), "%s has sleeves" % h)
	for h: StringName in sleeves:
		assert_true(bodies.has(h), "%s has a body" % h)


func test_marten_teammate_body() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 18601, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true,
		"loadouts": {0: _loadout(&"rook"), 1: _loadout(&"marten")}})
	await wait_frames(4)
	var mate: CrewController = _rt.crew_controller(1) as CrewController
	var body: Node = mate.get_node(^"Visual").get_child(0)
	assert_true(body.scene_file_path.contains("crew_marten"), "Marten's body (%s)" % body.scene_file_path)
	assert_true(AnimDriver.of(mate) != null, "an animated teammate")
	assert_false(body.find_children("*", "Skeleton3D", true, false).is_empty(), "a rigged body")
