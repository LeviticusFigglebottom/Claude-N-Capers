## B4-14: perk decks change behaviour through ENV A's existing hooks (public APIs only), on a
## standalone crew member (CrewController.spawn_for_range, no heist): max health / armor, dodge,
## armor regen delay, weapon damage / headshot bonus, armor pierce, interaction hold times.
## Keys without an ENV A hook (perk.* PARAMS, team.*, ammo pickup, armor bag, doctor bag speed,
## armor move penalty) are skipped here and filed as QBs (perk_decks.md "Hook coverage").
extends TestCase

const LIGHT_VEST: StringName = &"armor.light_vest"

var _root: Node3D = null
var _crew: CrewController = null


func before_all() -> void:
	ContentDB.clear_cache()


func before_each() -> void:
	Modifiers.clear_all()
	Net.start_solo("Player", 0)
	_root = Node3D.new()
	_root.name = "PerkBehaviourRoot"
	add_child(_root)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	_root.add_child(floor_body)
	var l: Loadout = CrewWeapons.build_loadout(null)
	l.armor = LIGHT_VEST
	_crew = CrewController.spawn_for_range(_root, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), l) as CrewController
	await wait_physics_frames(2)


func after_each() -> void:
	Modifiers.clear_all()
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_crew = null
	await wait_frames(1)


func after_all() -> void:
	ContentDB.clear_cache()


## The real path for the crew member's slot: personal perk source + the deck's TEAM sources.
func _apply_deck(deck: StringName, cards: int = 9) -> void:
	Modifiers.clear_all()
	var l: Loadout = Loadout.new()
	l.perk_deck = deck
	l.perk_deck_cards = cards
	Modifiers.set_source(_crew.slot, &"perk", LoadoutResolver.resolve(l).modifiers)
	var team: Dictionary = LoadoutResolver.crew_team_modifier_sources([l])
	for s: Variant in team:
		Modifiers.set_source(Modifiers.TEAM, StringName(s), team[s])
	_crew.health.reset_full()


func _hit(amount: float) -> Dictionary:
	return _crew.take_hit(Damage.info(amount, Enums.DamageType.MELEE, Enums.HitZone.BODY, &"test",
		_crew.global_position, Vector3.FORWARD), 0)


func test_health_mult_decks_raise_max_health() -> void:
	var base: float = Tweak.crew().base_health
	var expect: Dictionary = {&"perk.bulk": 2.0, &"perk.bloodletter": 1.4, &"perk.incumbent": 1.4,
		&"perk.long_odds": 1.4, &"perk.overlord": 1.8, &"perk.foreman": 1.2, &"perk.slipper": 1.0}  # LEAD (D-056): x team.health_mult
	for deck: StringName in expect:
		_apply_deck(deck)
		assert_near(_crew.health.max_health, base * float(expect[deck]), 0.01, "%s max health" % deck)
		assert_near(_crew.health.health, _crew.health.max_health, 0.01, "%s starts full" % deck)
	# Gating: Bulk card 1 only = +10%.
	_apply_deck(&"perk.bulk", 1)
	assert_near(_crew.health.max_health, base * 1.1, 0.01, "Bulk 1 card")


func test_armor_mult_decks_raise_max_armor() -> void:
	var vest: float = ContentDB.armor(LIGHT_VEST).armor
	var expect: Dictionary = {&"perk.ironclad": 1.35, &"perk.clean_sweep": 1.2, &"perk.foreman": 1.1,  # LEAD (D-056): x team.armor_mult
		&"perk.bulk": 1.0}
	for deck: StringName in expect:
		_apply_deck(deck)
		assert_near(_crew.health.max_armor, vest * float(expect[deck]), 0.01, "%s max armor" % deck)
	_apply_deck(&"perk.ironclad", 3)
	assert_near(_crew.health.max_armor, vest * 1.2, 0.01, "Ironclad 3 cards = +20%")


func test_dodge_decks_add_to_armor_dodge() -> void:
	var vest_dodge: float = ContentDB.armor(LIGHT_VEST).dodge
	var expect: Dictionary = {&"perk.slipper": 0.45, &"perk.prowler": 0.3, &"perk.hustler": 0.40,  # LEAD (D-056): + perk.crook.vest_dodge_add
		&"perk.incumbent": 0.15, &"perk.bulk": 0.0}
	for deck: StringName in expect:
		_apply_deck(deck)
		assert_near(_crew.health.dodge_chance(), clampf(vest_dodge + float(expect[deck]), 0.0, 1.0), 0.0001,
			"%s dodge" % deck)


func test_armor_regen_delay_decks_shorten_the_delay() -> void:
	var delay: float = Tweak.crew().armor_regen_delay_s
	var expect: Dictionary = {&"perk.hustler": 0.9, &"perk.clean_sweep": 0.9, &"perk.ironclad": 0.81, &"perk.bulk": 1.0}  # LEAD: x team
	for deck: StringName in expect:
		_apply_deck(deck)
		_hit(1.0)
		assert_near(_crew.health.regen_delay_left, delay * float(expect[deck]), 0.0001, "%s regen delay" % deck)
	# Ironclad 6 cards: the card-7 delay is not unlocked yet.
	_apply_deck(&"perk.ironclad", 6)
	_hit(1.0)
	assert_near(_crew.health.regen_delay_left, delay, 0.0001, "Ironclad 6 cards: no delay bonus")


func test_shared_cards_scale_weapon_damage_and_headshot_bonus() -> void:
	var ws: int = _crew.weapons.equipped_slot
	Modifiers.clear_all()
	var dmg0: float = _crew.weapons.damage_at(ws, 0.0)
	var head0: float = _crew.weapons.headshot_bonus(ws)
	assert_true(dmg0 > 0.0, "armed")
	_apply_deck(&"perk.composure", 9)
	assert_near(_crew.weapons.damage_at(ws, 0.0), dmg0 * 1.05, 0.0001, "card 8 +5% damage")
	assert_near(_crew.weapons.headshot_bonus(ws), head0 * 1.25, 0.0001, "card 2 headshot x1.25")
	_apply_deck(&"perk.composure", 7)
	assert_near(_crew.weapons.damage_at(ws, 0.0), dmg0, 0.0001, "card 8 locked at 7 cards")
	assert_near(_crew.weapons.headshot_bonus(ws), head0 * 1.25, 0.0001, "card 2 still on")


func test_armor_pierce_decks_raise_pierce_chance() -> void:
	var ws: int = _crew.weapons.equipped_slot
	Modifiers.clear_all()
	var ap0: float = float(CombatSystem.pierce_profile(_crew, ws)["armor_pierce"])
	var expect: Dictionary = {&"perk.slipper": 0.25, &"perk.bloodletter": 0.2}
	for deck: StringName in expect:
		_apply_deck(deck)
		assert_near(float(CombatSystem.pierce_profile(_crew, ws)["armor_pierce"]),
			clampf(ap0 + float(expect[deck]), 0.0, 1.0), 0.0001, "%s armor pierce" % deck)


## Prowler: InteractableComponent.duration_for applies the speed key the interactable carries
## (loot_manager: body bag, door/safe: lockpick, pager_system: pager answer).
func test_prowler_shortens_interaction_hold_times() -> void:
	_apply_deck(&"perk.prowler")
	var expect: Dictionary = {&"stealth.body_bag_speed_mult": 0.8, &"interaction.lockpick_speed_mult": 0.8,
		&"stealth.pager_answer_speed_mult": 0.9}
	for key: StringName in expect:
		var ic: InteractableComponent = InteractableComponent.new()
		ic.interaction_time_s = 10.0
		ic.speed_modifier_key = key
		_root.add_child(ic)
		assert_near(ic.duration_for(_crew), 10.0 * float(expect[key]), 0.0001, "Prowler %s" % key)
		ic.queue_free()


func test_hooks_that_need_a_full_heist_or_are_missing() -> void:
	skip("not exercised here: weapon.swap_speed_mult (timer is private to CrewWeapons), "
		+ "movement.crouch_speed_mult (needs physics movement), ability.shout_range_mult (needs police NPCs), "
		+ "team.* (no ENV A hook: Foreman crew health/armor/stamina, hostage DR, Ironclad crew regen delay), "
		+ "perk.* PARAMS mechanics, weapon.ammo_pickup_mult, deploy.armor_bag, "
		+ "interaction.doctor_bag_speed_mult, movement.armor_penalty_mult (no ENV A hook): QBs in perk_decks.md")
