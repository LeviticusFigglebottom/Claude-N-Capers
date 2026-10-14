## Roster wiring (lead round 186, Marten): every playable heister (B's roster, Heisters.ids()) has both a
## third-person body (CrewTweak.body_scenes) and first-person sleeves (FpViewmodelTweak.sleeve_scenes), and a
## teammate playing Marten or Jay spawns that body, animated. Owner: ENV P.
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
	for h: StringName in [&"marten", &"jay"]:
		assert_true(bodies.has(h) and sleeves.has(h), "%s wired (body + sleeves)" % h)
	for h: StringName in Heisters.ids():
		assert_true(bodies.has(h) and sleeves.has(h), "roster heister %s has a body and sleeves" % h)
	for h: StringName in bodies:
		assert_true(sleeves.has(h), "%s has sleeves" % h)
	for h: StringName in sleeves:
		assert_true(bodies.has(h), "%s has a body" % h)


func test_marten_teammate_body() -> void:
	await _teammate_body(&"marten", 18601)


func test_jay_teammate_body() -> void:
	await _teammate_body(&"jay", 19101)


func _teammate_body(heister: StringName, run_seed: int) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", run_seed, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true,
		"loadouts": {0: _loadout(&"rook"), 1: _loadout(heister)}})
	await wait_frames(4)
	var mate: CrewController = _rt.crew_controller(1) as CrewController
	var body: Node = mate.get_node(^"Visual").get_child(0)
	assert_true(body.scene_file_path.contains("crew_%s" % heister), "%s's body (%s)" % [heister, body.scene_file_path])
	assert_true(AnimDriver.of(mate) != null, "an animated teammate")
	assert_false(body.find_children("*", "Skeleton3D", true, false).is_empty(), "a rigged body")
