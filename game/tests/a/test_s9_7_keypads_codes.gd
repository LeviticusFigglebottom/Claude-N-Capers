## A2-04 S9.7: per-run codes (CodeRegistry, GameRng &"codes"), code notes, keypads, code_note
## variant slots.
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []


func before_each() -> void:
	await _launch(707)


func after_each() -> void:
	await _teardown()


func _launch(seed_value: int, map: PackedScene = null) -> void:
	_events.clear()
	_rt = await HeistLauncher.launch(&"unit_codes", seed_value, Enums.Difficulty.ROUTINE, self,
		{"map_packed": map if map != null else ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	var cb: Callable = func(item_id: StringName, slot: int) -> void: _events.append([item_id, slot])
	EventBus.item_picked_up.connect(cb)
	_conns.append([EventBus.item_picked_up, cb])


func _teardown() -> void:
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _codes() -> CodeRegistry:
	return _rt.service(CodeRegistry.SERVICE) as CodeRegistry


func _use(p: GameplayPrefab, seconds: float) -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, p.use_point.global_transform)
	await wait_physics_frames(1)
	ATestMaps.hold_interact(_rt, 0, p.net_id)
	await wait_seconds(seconds + 0.15)
	_rt.clear_bot_intent(0)
	await wait_physics_frames(2)


func test_codes_registered_and_deterministic_per_seed() -> void:
	assert_true(_codes() != null, "runtime service `codes`")
	assert_true(CodeRegistry.of(_rt) == _codes(), "CodeRegistry.of")
	var vault: String = _codes().code_for(&"vault")
	var office: String = _codes().code_for(&"office")
	assert_eq(vault.length(), 4, "4 digits")
	assert_true(vault.is_valid_int(), "digits only")
	assert_eq(_codes().code_for(&"vault"), vault, "rolled once per run")
	await _teardown()
	await _launch(707)
	assert_eq(_codes().code_for(&"office"), office, "same seed, other query order -> same code")
	assert_eq(_codes().code_for(&"vault"), vault, "same seed -> same code")
	var other: bool = false
	for s: int in [708, 709, 710, 711]:
		await _teardown()
		await _launch(s)
		if _codes().code_for(&"vault") != vault:
			other = true
			break
	assert_true(other, "other seeds roll other codes")


func test_read_note_then_keypad_opens_code_door() -> void:
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(0, 0, -8), func(n: Node) -> void:
		(n as Door).lock = Door.Lock.CODE
		(n as Door).code_group = &"vault") as Door
	var other_door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(6, 0, -8), func(n: Node) -> void:
		(n as Door).lock = Door.Lock.CODE
		(n as Door).code_group = &"office") as Door
	var side: Door = ATestMaps.add_prefab(_rt, "door", Vector3(-6, 0, -8), func(n: Node) -> void:
		(n as Door).lock = Door.Lock.ELECTRONIC) as Door
	var pad: Keypad = ATestMaps.add_prefab(_rt, "keypad", Vector3(3, 1.2, -4), func(n: Node) -> void:
		(n as Keypad).code_group = &"vault") as Keypad
	pad.targets = [NodePath("../%s" % side.name)]
	var note: CodeNote = ATestMaps.add_prefab(_rt, "code_note", Vector3(-3, 0, -3), func(n: Node) -> void:
		(n as CodeNote).code_group = &"vault") as CodeNote
	await wait_physics_frames(2)
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	crew.set_masked()
	assert_eq(pad.interactable.availability(crew), CodeRegistry.BLOCK_CODE_UNKNOWN, "unknown code blocks")
	# Holding on the keypad without the code is refused with the reason.
	_rt.teleport_crew(0, pad.use_point.global_transform)
	await wait_physics_frames(1)
	ATestMaps.hold_interact(_rt, 0, pad.net_id)
	await wait_physics_frames(3)
	assert_eq(_rt.interaction.blocked_reason(0), CodeRegistry.BLOCK_CODE_UNKNOWN, "HUD blocked reason")
	await wait_seconds(Tweak.interaction().keypad_s + 0.2)
	_rt.clear_bot_intent(0)
	await wait_physics_frames(2)
	assert_true(door.locked and not door.is_open, "door still locked")
	# Read the note.
	await _use(note, Tweak.interaction().read_note_s)
	assert_true(_codes().is_known(&"vault"), "code known to the crew")
	assert_false(_codes().is_known(&"office"), "only that group")
	assert_eq(_events.size(), 1, "item_picked_up")
	if not _events.is_empty():
		assert_eq(_events[0][0], &"item.code_note")
		assert_eq(int(_events[0][1]), 0, "reader slot")
	assert_eq(String(_codes().known_codes().get(&"vault", "")), _codes().code_for(&"vault"), "HUD query")
	assert_eq(note.code_text(), _codes().code_for(&"vault"), "note shows the code")
	# Any crew member can now use the keypad (crew-wide).
	var crew2: CrewController = _rt.crew_controller(1) as CrewController
	crew2.set_masked()
	assert_eq(pad.interactable.availability(crew2), InteractableComponent.BLOCK_NONE, "crew-wide knowledge")
	assert_near(pad.interactable.duration_for(crew), Tweak.interaction().keypad_s, 0.001, "keypad_s")
	await _use(pad, Tweak.interaction().keypad_s)
	assert_false(door.locked, "CODE door of the group unlocked")
	assert_true(door.is_open, "and opened")
	assert_true(other_door.locked and not other_door.is_open, "other group untouched")
	assert_true(side.is_open and not side.locked, "explicit target opened")
	assert_true(pad.used, "single use")
	assert_eq(pad.interactable.availability(crew), InteractableComponent.BLOCK_DISABLED)


func test_code_note_variant_slot_places_configured_note() -> void:
	await _teardown()
	var table: HeistVariantTable = HeistVariantTable.new()
	table.rules = [{"group": &"code_note", "pick": Vector2i(1, 1)}]
	var root: HeistMap = ATestMaps.basic(0, 0, {&"code_note": [&"desk", &"locker", &"bin"]}, table).instantiate() as HeistMap
	var note_scene: PackedScene = load("res://systems/prefabs/code_note/code_note.tscn") as PackedScene
	for vs: Node in root.get_node("Variants").get_children():
		var slot: VariantSlot = vs as VariantSlot
		slot.prefab = note_scene
		slot.params = {"code_group": &"vault"}
		slot.position = Vector3(_slot_x(slot.slot_id), 0.0, -3)
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	await _launch(707, ps)
	var notes: Array[CodeNote] = []
	var stack: Array[Node] = [_rt.map]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CodeNote:
			notes.append(n as CodeNote)
		for c: Node in n.get_children():
			stack.append(c)
	assert_eq(notes.size(), 1, "one note per run")
	if notes.is_empty():
		return
	assert_eq(notes[0].code_group, &"vault", "configure_variant params")
	assert_true(notes[0].net_id != 0, "claimed")
	await wait_physics_frames(1)
	await _use(notes[0], Tweak.interaction().read_note_s)
	assert_true(_codes().is_known(&"vault"), "reading the slot's note reveals the code")


## Deterministic x offset per slot id (no RNG in tests).
func _slot_x(slot_id: StringName) -> float:
	match slot_id:
		&"desk":
			return -4.0
		&"locker":
			return 0.0
	return 4.0
