## B4-17: the 3D weapon workshop (pd2_fidelity P6). Screen + WorkshopModel + WorkshopStage: weapon / mod
## selection rebuilds the WeaponVisual (marker attachment, stock-part hiding, akimbo offhand mirroring),
## stat deltas (sign + green / red), the DR preview equals LoadoutResolver, equip writes and saves the
## loadout, purchases spend spending cash (and refuse when short / locked), and slot focus moves the
## orbit camera onto the attach marker. Also the Workshop button on the loadout screen.
extends TestCase

const SCENE: String = "res://content/ui/workshop/workshop_screen.tscn"
const CORSAIR: StringName = &"weapon.corsair_ar"
const PAIR: StringName = &"weapon.akimbo_warden_45"
const MARSHAL: StringName = &"weapon.marshal_357"
const CONDOR: StringName = &"weapon.condor_50"

var _screen: WorkshopScreen
var _profile: PlayerProfile


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	SaveService.delete_profile(0)
	_profile = _make_profile()
	_screen = (load(SCENE) as PackedScene).instantiate() as WorkshopScreen
	_screen.setup(_profile)
	add_child(_screen)
	await wait_frames(1)


func after_each() -> void:
	_screen.queue_free()
	await wait_frames(1)


## Level 12, $40,000, owns the Corsair (equipped as primary, stock), the pair and the P9, and every mod
## except the suppressors.
static func _make_profile() -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 12
	p.cash = 40000
	p.owned_weapons.append_array([CORSAIR, PAIR] as Array[StringName])
	for m: Resource in ContentDB.all_mods():
		var id: StringName = (m as WeaponModDef).id
		if not String(id).contains("suppressor") and not p.owned_mods.has(id):
			p.owned_mods.append(id)
	p.loadout.primary = CORSAIR
	p.loadout.primary_mods = []
	return p


func _pick(t: int, id: StringName) -> void:
	_screen.select_slot(t)
	_screen.select_part(id)


func test_screen_instantiates_with_every_weapon() -> void:
	assert_true(_screen.stage != null and _screen.stage.visual.model != null, "a weapon is on the turntable")
	assert_eq(_screen.model.weapon_id, CORSAIR, "opens on the equipped primary")
	var ids: Array[StringName] = WorkshopModel.weapon_ids()
	assert_eq(ids.size(), ContentDB.all_weapons().size())
	assert_eq(_screen.weapon_list.item_count, ids.size() + 2, "every weapon + primary / secondary headers")
	assert_eq(_screen.slot_buttons.size(), ContentDB.weapon(CORSAIR).mod_slots.size(), "one button per mod slot")
	assert_true(_screen.focus_chain.has(_screen.weapon_list) and _screen.focus_chain.has(_screen.equip_button))


func test_states_owned_for_sale_locked() -> void:
	var m: WorkshopModel = _screen.model
	assert_eq(m.weapon_state(CORSAIR), WorkshopModel.ItemState.OWNED)
	assert_eq(m.weapon_state(MARSHAL), WorkshopModel.ItemState.FOR_SALE, "level 12 >= unlock level")
	assert_eq(m.weapon_state(CONDOR), WorkshopModel.ItemState.LOCKED, "unlock level 32")
	m.select_weapon(CORSAIR)
	assert_eq(m.mod_state(&""), WorkshopModel.ItemState.OWNED, "stock is always owned")
	assert_eq(m.mod_state(&"mod.corsair_iron_sights"), WorkshopModel.ItemState.OWNED, "default part")
	assert_eq(m.mod_state(&"mod.corsair_suppressor"), WorkshopModel.ItemState.FOR_SALE)
	assert_eq(m.mod_state(&"mod.rail_prism_scope"), WorkshopModel.ItemState.OWNED)


func test_mod_swap_rebuilds_visual_at_markers() -> void:
	var v: WeaponVisual = _screen.stage.visual
	_pick(Enums.ModType.SUPPRESSOR, &"mod.corsair_suppressor")
	assert_true(v.attached.has(Enums.ModType.SUPPRESSOR), "suppressor instanced")
	var sup: Node3D = v.attached[Enums.ModType.SUPPRESSOR]
	assert_eq(sup.get_parent(), v.get_base_marker(&"Muzzle"), "attached at the Muzzle marker")
	assert_true(sup.is_ancestor_of(v.get_marker(&"Muzzle")), "effective muzzle = the suppressor tip")
	_pick(Enums.ModType.SIGHT, &"mod.rail_prism_scope")
	var scope: Node3D = v.attached[Enums.ModType.SIGHT]
	assert_eq(scope.get_parent(), v.get_base_marker(&"SightRail"))
	assert_false(v.stock_part(Enums.ModType.SIGHT).visible, "iron sights hidden under the scope")
	_screen.select_part(&"")
	assert_false(v.attached.has(Enums.ModType.SIGHT), "back to stock")
	assert_true(v.stock_part(Enums.ModType.SIGHT).visible, "iron sights back")
	assert_true(v.attached.has(Enums.ModType.SUPPRESSOR), "other slots keep their part")


func test_akimbo_offhand_mirrors_mods() -> void:
	_screen.select_weapon(PAIR)
	var v: WeaponVisual = _screen.stage.visual
	assert_true(v.is_akimbo(), "the pair shows two guns")
	var rest: Node3D = v.get_base_marker(WeaponVisual.OFFHAND_MARKER)
	var expected: Transform3D = v.model.transform * WeaponVisual._transform_to(v.model, rest)
	assert_true(v.offhand.transform.is_equal_approx(expected), "offhand at the Offhand rest pose")
	_pick(Enums.ModType.SIGHT, &"mod.akimbo_w45_reflex_sight")
	_pick(Enums.ModType.SUPPRESSOR, &"mod.akimbo_w45_suppressor")
	for mods: Dictionary in [v.attached, v.attached_offhand]:
		assert_true(mods.has(Enums.ModType.SIGHT) and mods.has(Enums.ModType.SUPPRESSOR), "both guns carry the kit")
	assert_eq((v.attached_offhand[Enums.ModType.SUPPRESSOR] as Node).get_parent(),
			v.offhand.find_child("Muzzle", true, false), "offhand suppressor on the offhand's own muzzle")
	assert_false(v.offhand_stock_part(Enums.ModType.SIGHT).visible, "offhand iron sights hidden too")
	assert_true(v.offhand.is_ancestor_of(v.get_offhand_marker(&"Muzzle")))


func test_conflicting_pick_drops_the_other_part() -> void:
	_screen.select_weapon(PAIR)
	_pick(Enums.ModType.BARREL_EXT, &"mod.akimbo_w45_compensator")
	_pick(Enums.ModType.SUPPRESSOR, &"mod.akimbo_w45_suppressor")
	assert_eq(_screen.model.picks[Enums.ModType.BARREL_EXT], &"", "compensator removed")
	assert_eq(_screen.model.mod_ids(), [&"mod.akimbo_w45_suppressor"] as Array[StringName])
	assert_false(_screen.stage.visual.attached.has(Enums.ModType.BARREL_EXT))


func test_stat_deltas_sign_and_colour() -> void:
	_pick(Enums.ModType.MAGAZINE, &"mod.corsair_extended_mag")
	var rows: Dictionary = _screen.model.stat_rows()
	var mag: Dictionary = (rows["delta"] as Dictionary)["mag"]
	assert_true(float(mag["diff"]) > 0.0 and bool(mag["better"]), "bigger magazine is better")
	var conceal: Dictionary = (rows["delta"] as Dictionary)["concealment"]
	assert_true(float(conceal["diff"]) < 0.0 and not bool(conceal["better"]), "and hides worse")
	var t: HudTweak = HudTweak.load_default()
	var mag_l: Label = _screen.stat_delta_labels["mag"]
	assert_true(mag_l.text.begins_with("+"), "up arrow text: %s" % mag_l.text)
	assert_eq(mag_l.get_theme_color(&"font_color"), t.delta_better_color, "green")
	var con_l: Label = _screen.stat_delta_labels["concealment"]
	assert_true(con_l.text.begins_with("-"), "down text: %s" % con_l.text)
	assert_eq(con_l.get_theme_color(&"font_color"), t.delta_worse_color, "red")
	assert_eq(_screen.stat_delta_labels["damage"].text, "", "unchanged stats show no delta")
	assert_eq(_screen.stat_value_labels["mag"].text, str(int((rows["shown"] as Dictionary)["mag"])))


func test_deltas_compare_with_the_equipped_weapon() -> void:
	_profile.loadout.primary_mods = [&"mod.corsair_extended_mag"] as Array[StringName]
	_screen.select_weapon(CORSAIR)
	assert_eq(_screen.model.picks[Enums.ModType.MAGAZINE], &"mod.corsair_extended_mag", "equipped mods preloaded")
	assert_true(_screen.model.is_equipped())
	assert_true(_screen.equip_button.disabled, "already equipped")
	_screen.select_slot(Enums.ModType.MAGAZINE)
	_screen.select_part(&"")
	var mag: Dictionary = (_screen.model.stat_rows()["delta"] as Dictionary)["mag"]
	assert_true(float(mag["diff"]) < 0.0 and not bool(mag["better"]), "stock mag is worse than the equipped build")


func test_dr_preview_equals_loadout_resolver() -> void:
	_pick(Enums.ModType.SIGHT, &"mod.rail_prism_scope")
	_pick(Enums.ModType.SUPPRESSOR, &"mod.corsair_suppressor")
	var m: WorkshopModel = _screen.model
	var dr: Dictionary = m.dr_preview()
	var resolved: Loadout = LoadoutResolver.resolve(m.preview_loadout(), _profile)
	assert_eq(int(dr["detection_risk"]), resolved.detection_risk)
	assert_eq(int(dr["concealment"]), resolved.concealment_total)
	var now: Loadout = LoadoutResolver.resolve(_profile.loadout, _profile)
	assert_eq(int(dr["current_detection_risk"]), now.detection_risk)
	assert_true(int(dr["detection_risk"]) > now.detection_risk, "suppressor + scope raise DR")
	assert_eq(m.preview_loadout().primary_mods, [&"mod.corsair_suppressor", &"mod.rail_prism_scope"] as Array[StringName])
	assert_eq(_screen.detection_risk_label.text, UiText.t(&"ui.workshop.dr_preview",
			{"value": resolved.detection_risk, "current": now.detection_risk}))
	assert_eq(_screen.detection_risk_label.get_theme_color(&"font_color"), _screen.delta_color(false), "higher DR is red")


func test_equip_writes_loadout_and_saves() -> void:
	_pick(Enums.ModType.MAGAZINE, &"mod.corsair_extended_mag")
	_pick(Enums.ModType.SIGHT, &"mod.rail_reflex_sight")
	assert_false(_screen.equip_button.disabled)
	assert_true(_screen.equip_selected())
	var saved: PlayerProfile = SaveService.load_profile(0)
	assert_eq(saved.loadout.primary, CORSAIR)
	assert_eq(saved.loadout.primary_mods, [&"mod.rail_reflex_sight", &"mod.corsair_extended_mag"] as Array[StringName])
	assert_eq(saved.loadout.secondary, &"weapon.kestrel_p9", "secondary untouched")
	assert_true(_screen.equip_button.disabled, "now equipped")
	# A secondary goes to the secondary slot.
	_profile.owned_weapons.append(&"weapon.hornet_9")
	_screen.select_weapon(&"weapon.hornet_9")
	assert_true(_screen.equip_selected())
	assert_eq(SaveService.load_profile(0).loadout.secondary, &"weapon.hornet_9")
	assert_eq(SaveService.load_profile(0).loadout.primary, CORSAIR)


func test_equip_refused_for_unowned_weapon_or_part() -> void:
	_pick(Enums.ModType.SUPPRESSOR, &"mod.corsair_suppressor")
	assert_eq(_screen.model.equip_block(), WorkshopModel.BLOCK_MODS)
	assert_true(_screen.equip_button.disabled)
	assert_false(_screen.equip_selected())
	_screen.select_weapon(MARSHAL)
	assert_eq(_screen.model.equip_block(), WorkshopModel.BLOCK_WEAPON)
	assert_false(_screen.equip_selected())
	assert_eq(_profile.loadout.secondary, &"weapon.kestrel_p9", "loadout unchanged")


func test_purchase_deducts_cash_and_saves() -> void:
	var price: int = ContentDB.weapon(MARSHAL).price
	_screen.select_weapon(MARSHAL)
	assert_false(_screen.buy_button.disabled)
	assert_true(_screen.buy_selected())
	assert_eq(_profile.cash, 40000 - price)
	assert_true(_profile.owned_weapons.has(MARSHAL))
	var saved: PlayerProfile = SaveService.load_profile(0)
	assert_eq(saved.cash, 40000 - price, "purchase saved")
	assert_true(saved.owned_weapons.has(MARSHAL))
	assert_eq(_screen.model.equip_block(), &"", "now equippable")
	# A part: the Corsair suppressor.
	_screen.select_weapon(CORSAIR)
	_pick(Enums.ModType.SUPPRESSOR, &"mod.corsair_suppressor")
	var mod_price: int = ContentDB.mod(&"mod.corsair_suppressor").price
	assert_true(_screen.buy_selected())
	assert_eq(_profile.cash, 40000 - price - mod_price)
	assert_true(_profile.owned_mods.has(&"mod.corsair_suppressor"))


func test_purchase_refused_when_short_or_locked() -> void:
	_profile.cash = 1000
	_screen.select_weapon(MARSHAL)
	assert_true(_screen.buy_button.disabled, "disabled when short")
	assert_false(_screen.buy_selected())
	assert_false(_screen.model.buy_weapon(MARSHAL))
	assert_eq(_profile.cash, 1000, "nothing spent")
	assert_false(_profile.owned_weapons.has(MARSHAL))
	_profile.cash = 1000000
	_screen.select_weapon(CONDOR)
	assert_true(_screen.buy_button.disabled, "a locked weapon (and its parts) cannot be bought")
	assert_eq(_screen.message_label.text, UiText.t(&"ui.workshop.status.locked_level",
			{"level": ContentDB.weapon(CONDOR).unlock_level}))
	assert_false(_screen.model.buy_weapon(CONDOR), "locked by level")
	assert_false(_screen.model.buy_weapon(CORSAIR), "already owned")
	assert_eq(_profile.cash, 1000000)


func test_focus_moves_camera_to_marker() -> void:
	var st: WorkshopStage = _screen.stage
	for t: int in [Enums.ModType.SIGHT, Enums.ModType.MAGAZINE, Enums.ModType.FOREGRIP]:
		_screen.select_slot(t)
		st.settle()
		var marker: Node3D = st.slot_marker(t)
		assert_true(marker != null)
		var p: Vector3 = marker.global_position
		assert_true(st.goal_target.distance_to(p) < 0.001, "orbit target on the marker")
		var cam: Transform3D = st.camera.global_transform
		assert_near(cam.origin.distance_to(p), st.goal_distance, 0.001, "camera at the focus distance")
		assert_true((p - cam.origin).normalized().dot(-cam.basis.z) > 0.9999, "marker centred in view")
		assert_true(st.goal_distance < st.overview_distance, "zoomed in")
		assert_true(st.gizmo.visible and st.gizmo.global_position.distance_to(p) < 0.001, "gizmo on the marker")
	st.reset_view()
	st.settle()
	assert_false(st.gizmo.visible)
	assert_true(st.target.distance_to(st.bounds.get_center()) < 0.001, "overview orbits the weapon centre")


func test_camera_eases_and_orbit_zoom_limits() -> void:
	var st: WorkshopStage = _screen.stage
	st.settle()
	var before: float = st.distance
	_screen.select_slot(Enums.ModType.SIGHT)
	await wait_frames(3)
	assert_true(st.distance < before and st.distance > st.goal_distance, "eases toward the focus")
	st.reset_view()
	for i: int in range(60):
		st.zoom(0.5)
	assert_true(st.goal_distance >= st.overview_distance * st.tweak.zoom_min_mult - 0.0001, "zoom-in limit")
	st.orbit(0.0, 500.0)
	assert_near(st.goal_pitch_deg, st.tweak.pitch_limit_deg, 0.001, "pitch clamped")
	st.pan(Vector2(100.0, 0.0))
	assert_true(st.goal_target.distance_to(st.bounds.get_center()) <= st.bounds.size.length() * 0.5 * st.tweak.pan_limit_radii + 0.001)


func test_loadout_screen_opens_and_closes_workshop() -> void:
	var p: PlayerProfile = _make_profile()
	p.owned_weapons.append(&"weapon.hornet_9")
	var ls: LoadoutScreen = (load("res://content/ui/menus/loadout.tscn") as PackedScene).instantiate() as LoadoutScreen
	ls.setup(p)
	add_child(ls)
	await wait_frames(1)
	var ws: WorkshopScreen = ls.open_workshop()
	await wait_frames(1)
	assert_true(ws.is_inside_tree() and ws.profile == p, "workshop over the loadout, same profile")
	ws.select_weapon(&"weapon.hornet_9")
	assert_true(ws.equip_selected())
	ws.back_requested.emit()
	await wait_frames(2)
	assert_eq(ls.workshop, null, "closed")
	assert_eq(LoadoutScreen._selected_id(ls.weapon_option), &"weapon.hornet_9", "loadout shows the new secondary")
	assert_eq(ls.current_loadout().secondary, &"weapon.hornet_9")
	assert_eq(ls.current_loadout().primary, CORSAIR, "primary kept")
	ls.queue_free()
	await wait_frames(1)
