## OF-A3 (QC-63): hack_terminal.reveals_code_group (a finished hack reveals a keypad code like a code_note) and the
## runtime variant-group reveal (HeistMission.reveal_variant_group / code_note.reveals_variant_group: OF's planner
## `[code_hint]` -> `code_pc`), the same effect as an asset's `reveals`, mirrored to clients.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(run_seed: int) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", run_seed, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)


func test_finished_hack_reveals_its_code_group() -> void:
	await _launch(6301)
	var ht: HackTerminal = ATestMaps.add_prefab(_rt, "hack_terminal", Vector3(0, 0, -4), func(p: GameplayPrefab) -> void:
		(p as HackTerminal).duration_s = 0.3
		(p as HackTerminal).interruptions = Vector2i(0, 0)
		(p as HackTerminal).reveals_code_group = &"vault") as HackTerminal
	await wait_physics_frames(2)
	var reg: CodeRegistry = CodeRegistry.of(ht)
	assert_false(reg.is_known(&"vault"), "unknown before the hack")
	ht.start_hack(1)
	await wait_seconds(0.2)
	assert_false(reg.is_known(&"vault"), "still unknown mid-hack")
	await wait_seconds(0.4)
	assert_eq(ht.state, HackTerminal.State.DONE, "hack finished")
	assert_true(reg.is_known(&"vault"), "the finished hack reveals the code")
	assert_eq(int((reg.net_state()[&"vault"] as Array)[1]), 1, "credited to the slot that started it")
	var ht2: HackTerminal = ATestMaps.add_prefab(_rt, "hack_terminal", Vector3(3, 0, -4)) as HackTerminal
	ht2.configure_variant({"reveals_code_group": &"vault_b"})
	assert_eq(ht2.reveals_code_group, &"vault_b", "variant param")


func test_runtime_variant_group_reveal() -> void:
	await _launch(6302)
	var mission: HeistMission = _rt.mission
	var seen: Array[StringName] = []
	var cb: Callable = func(g: StringName) -> void: seen.append(g)
	_rt.preplan.group_revealed.connect(cb)
	assert_false(mission.is_variant_revealed(&"code_pc"), "not known at the start")
	assert_false(_rt.net_sync.services_state().has(HeistNetSync.SVC_REVEALS), "nothing to mirror yet")
	# The planner: a code_note carrying only a variant group.
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var note: CodeNote = ATestMaps.add_prefab(_rt, "code_note", Vector3(0, 0, -3)) as CodeNote
	note.configure_variant({"reveals_variant_group": &"code_pc"})
	await wait_physics_frames(1)
	note.interactable.completed.emit(c)
	assert_true(mission.is_variant_revealed(&"code_pc"), "reading the planner reveals code_pc")
	assert_eq(_rt.preplan.reveals(), [&"code_pc"] as Array[StringName], "as an asset's reveals")
	assert_false(_rt.preplan.is_active(), "not a bought asset")
	assert_eq(seen, [&"code_pc"] as Array[StringName], "group_revealed (HeistMission._on_variant_revealed)")
	assert_true(mission.reveal_variant_group(&"keycard"), "the mission API reveals too")
	assert_false(mission.reveal_variant_group(&"keycard"), "once")
	# Mirror: a client's PreplanAssets adopts the server's runtime reveals.
	var svc: Dictionary = _rt.net_sync.services_state()
	assert_eq(svc.get(HeistNetSync.SVC_REVEALS), ["code_pc", "keycard"], "replicated with the services state")
	var client: PreplanAssets = PreplanAssets.new()
	client.apply_reveals_net_state(svc[HeistNetSync.SVC_REVEALS] as Array)
	assert_eq(client.reveals(), [&"code_pc", &"keycard"] as Array[StringName], "client knows both groups")
	_rt.preplan.group_revealed.disconnect(cb)
