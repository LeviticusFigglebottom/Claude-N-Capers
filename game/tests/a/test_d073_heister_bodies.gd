## D-073: the crew's third-person body follows Loadout.heister (CrewTweak.body_scenes: crew_rook / _sable / _dutch /
## _wren); generic crew keep the capsule placeholder. Teammates are animated (AnimDriver), the mask sits on the
## body's Head/Socket, and the local human's own body is culled from its camera (FIRST_PERSON_HIDDEN_LAYER).
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
	l.mask = &"mask.gilded_heron"
	return l


func test_bodies_by_heister() -> void:
	if Tweak.crew().body_scenes.is_empty():
		skip("no heister bodies")
		return
	_rt = await HeistLauncher.launch(&"unit_map", 7301, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 2, "crew_ai": false, "skip_casing": true,
		"loadouts": {0: _loadout(&"rook"), 1: _loadout(&"sable")}})
	await wait_frames(4)
	var me: CrewController = _rt.crew_controller(0) as CrewController
	var mate: CrewController = _rt.crew_controller(1) as CrewController
	var generic: CrewController = _rt.crew_controller(2) as CrewController
	var mate_body: Node = mate.get_node(^"Visual").get_child(0)
	assert_true(mate_body.scene_file_path.contains("crew_sable"), "Sable's body (%s)" % mate_body.scene_file_path)
	assert_true(AnimDriver.of(mate) != null, "an animated teammate")
	# LEAD r281: an AI slot launched without a heister wears the first unworn one (no capsule placeholder)
	assert_true(generic.get_node_or_null(^"Visual/Placeholder") == null, "a bot without a pick: no capsule")
	assert_true(generic.heister != &"" and generic.heister != &"rook" and generic.heister != &"sable",
		"it wears an unworn heister (%s)" % generic.heister)
	var my_body: Node = me.get_node(^"Visual").get_child(0)
	assert_true(my_body.scene_file_path.contains("crew_rook"), "Rook's body")
	for g: Node in my_body.find_children("*", "VisualInstance3D", true, false):
		assert_eq((g as VisualInstance3D).layers, CrewView.FIRST_PERSON_HIDDEN_LAYER, "own body culled: %s" % g.name)
	mate.set_masked()
	await wait_frames(2)
	var mask: Node3D = CrewView.of(mate).mask_node()
	assert_true(mask != null and my_body != mask and mate_body.is_ancestor_of(mask), "mask on the body's Head/Socket")
