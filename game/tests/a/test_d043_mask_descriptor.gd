## D-043 / QA-25: Loadout.mask_descriptor. CrewView builds the mask on every peer from the loadout's
## descriptor (MaskCatalog.from_descriptor), or from the preset Loadout.mask when it is {}.
## CrewView.set_mask_descriptor replaces it (server replicates it, reliable authority RPC).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(loadouts: Dictionary) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 43, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "skip_casing": true, "crew_ai": false,
			"loadouts": loadouts})
	await wait_frames(2)


func _custom_descriptor(mask_id: String) -> Dictionary:
	var d: Dictionary = (MaskCatalog.tweak().default_composition as Dictionary).duplicate(true)
	d["id"] = mask_id
	return d


func test_descriptor_on_loadout_builds_mask_at_head_socket() -> void:
	var l: Loadout = Loadout.new()
	l.mask = &"mask.custom.2"  # custom: unresolvable without the owner's profile
	l.mask_descriptor = _custom_descriptor("mask.custom.2")
	var plain: Loadout = Loadout.new()
	plain.mask = &"mask.custom.3"  # custom without descriptor: no mask on peers without the profile
	await _launch({0: l, 1: plain})
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var other: CrewController = _rt.crew_controller(1) as CrewController
	assert_eq(c.loadout.mask_descriptor, l.mask_descriptor, "descriptor kept on the resolved loadout")
	c.set_masked()
	other.set_masked()
	await wait_frames(1)
	var view: CrewView = CrewView.of(c)
	var m: Node3D = view.mask_node()
	assert_true(m != null, "mask built from the descriptor")
	if m != null:
		assert_eq(m.get_parent().name, &"Socket", "under Head/Socket")
		assert_eq(m.get_parent().get_parent().name, &"Head")
	assert_true(CrewView.of(other).mask_node() == null, "custom id without descriptor: no mask")
	assert_eq(view.mask_descriptor, c.loadout.mask_descriptor, "CrewView.mask_descriptor alias")


func test_set_mask_descriptor_rebuilds_and_preset_fallback() -> void:
	var l: Loadout = Loadout.new()
	l.mask = &"mask.gilded_heron"
	await _launch({0: l, 1: l})
	var c: CrewController = _rt.crew_controller(1) as CrewController
	assert_eq(c.loadout.mask_descriptor, {}, "{} = preset")
	c.set_masked()
	await wait_frames(1)
	var view: CrewView = CrewView.of(c)
	var preset: Node3D = view.mask_node()
	assert_true(preset != null, "preset mask from MaskCatalog when the descriptor is {}")
	var d: Dictionary = _custom_descriptor("mask.custom.1")
	CrewView.of(c).set_mask_descriptor(d)
	var custom: Node3D = view.mask_node()
	assert_true(custom != null and custom != preset, "rebuilt from the new descriptor")
	assert_eq(c.loadout.mask_descriptor, d)
	d["base"] = "changed"
	assert_ne(c.loadout.mask_descriptor.get("base"), "changed", "stored as a copy")
	CrewView.of(c).set_mask_descriptor(c.loadout.mask_descriptor)
	assert_true(view.mask_node() == custom, "same descriptor: no rebuild")
	view.mask_descriptor = {}
	assert_eq(c.loadout.mask_descriptor, {}, "alias setter goes through the crew member")
	assert_true(view.mask_node() != null and view.mask_node() != custom, "back to the preset")
