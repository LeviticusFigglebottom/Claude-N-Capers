## PO6-12: the firing range uses the real player viewmodel path. CrewView + FpViewmodel own the first-person weapon
## (no static RangeViewmodel under the camera); a picked weapon goes to its own slot and the other slot is kept, so
## the crew swaps with holster + draw; the panels/readout follow the equipped slot; fire, reload and ADS drive the arms;
## the re-arm keeps the drawn weapon.
extends TestCase

const SCENE: String = "res://content/range/firing_range.tscn"
const P9: StringName = &"weapon.kestrel_p9"
const CORSAIR: StringName = &"weapon.corsair_ar"
const PLOWMAN: StringName = &"weapon.plowman_12"
const SUPPRESSOR: StringName = &"mod.corsair_suppressor"

var _range: FiringRange = null


func after_each() -> void:
	if _range != null and is_instance_valid(_range):
		_range.queue_free()
	_range = null
	await wait_frames(2)


func _crew_range() -> FiringRange:
	if not RangeCrewBridge.available():
		skip("CrewController.spawn_for_range not in this tree")
		return null
	_range = (load(SCENE) as PackedScene).instantiate() as FiringRange
	add_child(_range)
	await wait_frames(2)
	await wait_physics_frames(10)
	return _range


func _fp(r: FiringRange) -> FpViewmodel:
	var v: CrewView = CrewView.of(r.crew)
	return v.fp_viewmodel() if v != null else null


func _weapons(r: FiringRange) -> CrewWeapons:
	return r.crew.get(&"weapons") as CrewWeapons


## Run the crew's own weapon ticks for `s` seconds with `intent` (what PlayerInput feeds it in aim mode).
func _drive(r: FiringRange, intent: CrewIntent, s: float) -> void:
	r.crew.call(&"apply_intent", intent)
	await wait_seconds(s)


func test_default_loadout_fills_both_slots_and_starts_on_the_starter() -> void:
	var l: Loadout = FiringRange.default_loadout()
	assert_ne(l.primary, &"", "a primary to swap to")
	assert_ne(l.secondary, &"", "a secondary to swap to")
	assert_eq(FiringRange.starter_slot(), int(ContentDB.weapon(P9).slot), "the overall starter is the P9's slot")


func test_real_fp_arms_carry_the_range_weapon() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	var cam: Camera3D = RangeCrewBridge.camera(r.crew)
	assert_true(cam.get_node_or_null(RangeCrewBridge.VIEWMODEL_NAME) == null, "no static range viewmodel")
	var view: CrewView = CrewView.of(r.crew)
	assert_false(view.external_viewmodel, "CrewView still owns the camera")
	assert_eq(r.current_weapon_id(), P9)
	assert_eq(RangeCrewBridge.equipped_slot(r.crew), int(Enums.WeaponSlot.SECONDARY), "crew holds the starter P9")
	assert_true(r.viewmodel != null and r.viewmodel == RangeCrewBridge.weapon_visual(r.crew), "range reads CrewView's")
	await wait_frames(2)
	assert_eq(r._finished_wv, r.viewmodel, "loadout finish applied to the live FP weapon")
	assert_eq(r.viewmodel.weapon.id, P9)
	var fp: FpViewmodel = _fp(r)
	if fp == null:
		skip("no FP arms scene in this tree (static viewmodel path)")
		return
	assert_true(fp.is_ancestor_of(r.viewmodel), "the weapon rides the arms' weapon bone")
	assert_eq(fp.weapon_visual, r.viewmodel)


func test_pick_keeps_other_slot_and_swaps_with_holster_and_draw() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	r.select_weapon(CORSAIR)
	assert_eq(r.loadout.primary, CORSAIR)
	assert_eq(r.loadout.secondary, P9, "the secondary stays for swapping")
	assert_eq(r.active_slot, int(Enums.WeaponSlot.PRIMARY))
	assert_eq(r.weapon_def.id, CORSAIR, "panels follow the pick")
	r.select_weapon(PLOWMAN)
	assert_eq(r.loadout.primary, PLOWMAN, "a pick replaces only its own slot")
	await wait_seconds(1.5)
	assert_eq(RangeCrewBridge.weapon_visual(r.crew).weapon.id, PLOWMAN, "the FP model is the picked weapon")
	# Slot key in aim mode: the crew's own equip.
	var i: CrewIntent = CrewIntent.new()
	i.weapon_slot = Enums.WeaponSlot.SECONDARY
	r.crew.call(&"apply_intent", i)
	await wait_physics_frames(2)
	assert_eq(r.active_slot, int(Enums.WeaponSlot.SECONDARY), "range follows the swap")
	assert_eq(r.current_weapon_id(), P9)
	assert_eq(r.weapon_def.id, P9, "panel shows the swapped-to weapon")
	var fp: FpViewmodel = _fp(r)
	if fp != null:
		assert_eq(fp.action, int(FpViewmodel.Action.SWAP), "holster + draw clips play")
	await wait_seconds(1.5)
	assert_eq(RangeCrewBridge.weapon_visual(r.crew).weapon.id, P9, "the FP model is the P9 after the swap")
	if fp != null:
		assert_eq(fp.weapon_visual.weapon.id, P9)
		assert_eq(fp.anim_set, ContentDB.weapon(P9).anim_set)


func test_mods_apply_to_the_equipped_slot_and_show_on_the_model() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	r.select_weapon(CORSAIR)
	if ContentDB.mod(SUPPRESSOR) == null:
		skip("no %s" % SUPPRESSOR)
		return
	r.set_mod(int(ContentDB.mod(SUPPRESSOR).mod_type), SUPPRESSOR)
	assert_true(r.loadout.primary_mods.has(SUPPRESSOR), "mod on the primary")
	assert_true(r.loadout.secondary_mods.is_empty(), "secondary untouched")
	await wait_seconds(1.5)
	var wv: WeaponVisual = RangeCrewBridge.weapon_visual(r.crew)
	assert_eq(wv.weapon.id, CORSAIR)
	assert_true(wv.attached.size() > 0, "the attachment is on the FP model")


func test_fire_reload_and_ads_drive_the_arms() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	var fp: FpViewmodel = _fp(r)
	if fp == null:
		skip("no FP arms scene in this tree")
		return
	r.select_weapon(CORSAIR)
	await wait_seconds(1.5)
	var w: CrewWeapons = _weapons(r)
	var mag0: int = w.mag(Enums.WeaponSlot.PRIMARY)
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = float(r.crew.get(&"look_yaw"))
	i.look_pitch = float(r.crew.get(&"look_pitch"))
	i.fire = true
	await _drive(r, i, 0.05)
	assert_true(w.mag(Enums.WeaponSlot.PRIMARY) < mag0, "a shot went off")
	assert_eq(fp.action, int(FpViewmodel.Action.FIRE), "fire clip on the arms")
	i = CrewIntent.new()
	i.look_yaw = float(r.crew.get(&"look_yaw"))
	i.look_pitch = float(r.crew.get(&"look_pitch"))
	i.reload = true
	await _drive(r, i, 0.1)
	assert_true(w.reloading, "reload started")
	assert_eq(fp.action, int(FpViewmodel.Action.RELOAD), "reload clip on the arms")
	await wait_seconds(w.stats(Enums.WeaponSlot.PRIMARY).reload_time_s + 0.3)
	i = CrewIntent.new()
	i.look_yaw = float(r.crew.get(&"look_yaw"))
	i.look_pitch = float(r.crew.get(&"look_pitch"))
	i.aim = true
	await _drive(r, i, 1.0)
	assert_true(fp.ads_weight > 0.5, "ADS blends the arms in (%.2f)" % fp.ads_weight)


func test_rearm_keeps_the_drawn_weapon() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	r.select_weapon(CORSAIR)
	await wait_seconds(1.5)
	var i: CrewIntent = CrewIntent.new()
	i.weapon_slot = Enums.WeaponSlot.SECONDARY
	r.crew.call(&"apply_intent", i)
	await wait_seconds(1.5)
	var w: CrewWeapons = _weapons(r)
	w.set_ammo(Enums.WeaponSlot.SECONDARY, 0, 0)
	await wait_seconds(0.6)  # the HUD model polls at its poll_hz
	assert_eq(w.equipped_slot, int(Enums.WeaponSlot.SECONDARY), "still holding the secondary")
	assert_eq(w.mag(Enums.WeaponSlot.SECONDARY), w.mag_size(Enums.WeaponSlot.SECONDARY), "re-armed in place")
	r.reset_targets()
	assert_eq(w.equipped_slot, int(Enums.WeaponSlot.SECONDARY), "reset re-arms without re-equipping")
