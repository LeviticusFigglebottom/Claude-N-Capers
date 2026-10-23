## D-155: melee unlocks by player level and is never sold (PD2). MeleeGate is derived from the level (nothing saved);
## the loadout picker lists every melee, locked ones disabled with "(level N)"; a locked saved pick falls back
## to the starter knife.
extends TestCase

const SLOT: int = 0


func before_all() -> void:
	ContentDB.clear_cache()
	SaveService.root_dir = BTestUtil.profile_root()
	OnboardingTips.persist = false


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func _melees() -> Array[MeleeDef]:
	var out: Array[MeleeDef] = []
	for r: Variant in ContentDB.all_melees():
		out.append(r as MeleeDef)
	return out


func test_levels_are_pd2_shaped() -> void:
	var free_sets: Dictionary = {}
	var by_id: Dictionary = {}
	for d: MeleeDef in _melees():
		by_id[d.id] = d.unlock_level
		if d.unlock_level == 0:
			free_sets[d.anim_set] = true
	assert_eq(int(by_id.get(MeleeGate.DEFAULT_ID, -1)), 0, "the starter knife is free from the start")
	assert_true(free_sets.has(&"melee_blunt"), "at least one blunt melee from the start (D-155)")
	for heavy: StringName in [&"melee.sledgehammer", &"melee.fire_axe"]:
		assert_true(int(by_id.get(heavy, 0)) >= 60, "%s unlocks late (%d)" % [heavy, int(by_id.get(heavy, 0))])
	assert_false(&"price" in (_melees()[0] as Object), "no cash price on MeleeDef (D-155)")


func test_gate_follows_the_level() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var axe: MeleeDef = ContentDB.melee(&"melee.fire_axe")
	p.level = axe.unlock_level - 1
	assert_false(MeleeGate.is_unlocked(p, axe), "one level short")
	assert_eq(MeleeGate.usable(p, axe.id), MeleeGate.DEFAULT_ID, "a locked pick falls back to the knife")
	p.level = axe.unlock_level
	assert_true(MeleeGate.is_unlocked(p, axe), "unlocked at its level")
	assert_eq(MeleeGate.usable(p, axe.id), axe.id)
	assert_true(MeleeGate.is_unlocked(null, ContentDB.melee(MeleeGate.DEFAULT_ID)), "the knife needs no profile")


func _screen(level: int, melee: StringName) -> MenuFlow:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = level
	p.xp = XpCurve.xp_for_level(level)
	p.loadout.melee = melee
	SaveService.save_profile(p, SLOT)
	var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(flow)
	await wait_frames(4)
	flow.show_hub()
	flow.open_station(&"armory")
	await wait_frames(4)
	return flow


func test_picker_disables_locked_melees() -> void:
	var flow: MenuFlow = await _screen(20, &"melee.lead_pipe")
	var slot: ItemSlot = flow.loadout_screen.melee_option
	assert_eq(slot.item_count, _melees().size(), "every melee is listed")
	for i: int in range(slot.item_count):
		var d: MeleeDef = ContentDB.melee(StringName(slot.get_item_metadata(i)))
		var locked: bool = d.unlock_level > 20
		assert_eq(slot.is_item_disabled(i), locked, "%s disabled iff locked" % d.id)
		assert_eq(slot.get_item_text(i).contains(UiText.t(&"ui.loadout.melee_locked", {"name": "", "level": d.unlock_level}).strip_edges()),
				locked, "%s shows its unlock level iff locked: %s" % [d.id, slot.get_item_text(i)])
	assert_eq(LoadoutScreen._selected_id(slot), &"melee.lead_pipe", "an unlocked saved pick stays")
	flow.queue_free()
	await wait_frames(2)


func test_locked_saved_pick_falls_back_to_the_knife() -> void:
	var flow: MenuFlow = await _screen(5, &"melee.sledgehammer")  # e.g. a pre-D-155 save
	var slot: ItemSlot = flow.loadout_screen.melee_option
	assert_eq(LoadoutScreen._selected_id(slot), MeleeGate.DEFAULT_ID, "shows the knife")
	assert_eq(flow.loadout_screen.current_loadout().melee, MeleeGate.DEFAULT_ID, "and equips it")
	flow.queue_free()
	await wait_frames(2)
