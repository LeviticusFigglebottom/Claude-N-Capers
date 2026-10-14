## P / lead (ND 1 Hz stealth stutter): LocalHudModel marker resolution walks the whole map per tag, so with one
## unresolvable marker_tag it must not re-query the resolved objectives, and the unresolved one backs off and gives
## up (MARKER_MAX_TRIES): the lookup count stays bounded however long the heist runs.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_unresolvable_marker_tag_does_not_requery_resolved_ones_and_backs_off() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1212, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)
	var hud: LocalHudModel = _rt.hud_model
	var npc: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(3, 0.05, -6)), {})
	npc.objective_tag = &"t_found"
	await wait_physics_frames(2)
	_rt.mission.add_objective(&"found", &"obj.found", Enums.ObjectiveState.ACTIVE, {"marker_tags": [&"t_found"]})
	_rt.mission.add_objective(&"lost", &"obj.lost", Enums.ObjectiveState.ACTIVE, {"marker_tags": [&"t_nowhere"]})
	await wait_seconds(0.5)
	var ids: Array[StringName] = []
	for m: Dictionary in hud.objective_markers:
		ids.append(StringName(m["id"]))
	assert_true(ids.has(&"found"), "the tagged NPC is a marker (NpcBase.objective_tag)")
	assert_false(ids.has(&"lost"), "an unresolvable tag shows no marker")
	var after_first: int = hud.marker_lookups
	await wait_seconds(3.0)
	var lookups_3s: int = hud.marker_lookups - after_first
	assert_true(lookups_3s <= 2, "only the unresolved objective retries, backing off (%d lookups in 3 s)" % lookups_3s)
	await wait_seconds(8.0)
	var total: int = hud.marker_lookups
	assert_true(total <= 2 + LocalHudModel.MARKER_MAX_TRIES, "lookups bounded (%d)" % total)
	await wait_seconds(4.0)
	assert_true(hud.marker_lookups - total <= 1, "gave up retrying (%d more)" % (hud.marker_lookups - total))
	# A data update re-resolves (QC-60): the lost objective gets a tag that now exists.
	_rt.mission.update_objective_data(&"lost", {"marker_tags": [&"t_found"]})
	await wait_seconds(0.3)
	ids.clear()
	for m: Dictionary in hud.objective_markers:
		ids.append(StringName(m["id"]))
	assert_true(ids.has(&"lost"), "a data update re-resolves an objective that had given up")
