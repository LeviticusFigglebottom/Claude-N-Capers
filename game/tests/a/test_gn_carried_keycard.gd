## D-103 §6 / QC-52 (Gallery Night curator): a KeycardPickup with `carrier_tag` rides on the NPC spawned with that
## tag, hidden and not interactable, until the carrier is tied / downed / dominated / dead (PD2: tie or kill the
## keyholder). Then it can be taken (carried_item_s); a dead carrier's card stays on the floor where they fell, even
## once the body is bagged. Replicated (`cr`, `rel`). No such NPC: an ordinary pickup.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1108, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)


func _curator(pos: Vector3) -> NpcBase:
	return _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, pos), {"idle_activity": &"sit", "tags": [&"civ_curator"]})


func _card(pos: Vector3, tag: StringName = &"civ_curator") -> KeycardPickup:
	return ATestMaps.add_prefab(_rt, "keycard_pickup", pos, func(p: GameplayPrefab) -> void:
		(p as KeycardPickup).carrier_tag = tag) as KeycardPickup


func test_gn_card_rides_on_the_curator_until_she_is_tied() -> void:
	await _launch()
	var cur: NpcBase = _curator(Vector3(2, 0.05, -3))
	var card: KeycardPickup = _card(Vector3(-5, 1, 5))
	await wait_physics_frames(3)
	assert_eq(card.carrier_id, cur.net_id, "bound to the tagged NPC")
	assert_false(card.released, "carried")
	assert_false(card.visible or card.interactable.enabled, "hidden, no prompt")
	assert_true(card.global_position.distance_to(cur.global_position) < 1.2, "rides on her")
	(cur.get_node(^"Brain") as CivilianBrain).mode = CivilianBrain.Mode.TIED
	await wait_physics_frames(2)
	assert_true(card.released and card.visible and card.interactable.enabled, "tied: the card can be taken")
	assert_near(card.interactable.interaction_time_s, Tweak.interaction().carried_item_s, 0.001, "1 s take")
	var client: KeycardPickup = _card(Vector3(-6, 1, 5), &"civ_curator")
	await wait_physics_frames(1)
	client._apply_net_state(card._net_state())
	assert_true(client.released and client.visible and client.interactable.enabled, "client mirrors the release")
	assert_eq(client.carrier_id, cur.net_id, "client knows the carrier")
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	card._on_completed(crew)
	assert_true(crew.item_count(KeycardPickup.ITEM) == 1, "crew has the keycard")


func test_gn_dead_carrier_drops_the_card_where_she_fell() -> void:
	await _launch()
	var cur: NpcBase = _curator(Vector3(2, 0.05, -3))
	var card: KeycardPickup = _card(Vector3(-5, 1, 5))
	await wait_physics_frames(3)
	var stood_at: Vector3 = cur.global_position
	cur.die({}, 0)
	await wait_physics_frames(2)
	# D-121: the body lies at the ground-snapped corpse anchor (the root after death), not where she stood;
	# the card, the ammo drop and the body bag all use it.
	var lies_at: Vector3 = cur.global_position
	assert_true(card.released and card.visible and card.interactable.enabled, "dead: lootable")
	assert_true(card.global_position.distance_to(lies_at) < 0.3, "on the floor at the body")
	assert_true(absf(card.global_position.y - stood_at.y) < 0.3, "at floor height")
	var drop: Vector3 = card.global_position
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	crew.body_bags = 1
	assert_true((_rt.service(G.SVC_LOOT) as LootManager).bag_body(crew, cur) != null, "body bagged")
	await wait_physics_frames(2)
	assert_true(is_instance_valid(card) and card.visible, "bagging the body leaves the card")
	assert_true(card.global_position.distance_to(drop) < 0.01, "and it stays put")


func test_gn_untagged_card_and_missing_carrier_are_ordinary_pickups() -> void:
	await _launch()
	var lost: KeycardPickup = _card(Vector3(-5, 1, 5), &"civ_nobody")
	var plain: KeycardPickup = _card(Vector3(-4, 1, 5), &"")
	await wait_physics_frames(3)
	assert_true(lost.released and lost.visible and lost.interactable.enabled, "no carrier: lies where placed")
	assert_true(lost.global_position.distance_to(Vector3(-5, 1, 5)) < 0.01, "not moved")
	assert_true(plain.visible and plain.interactable.enabled, "plain pickup unchanged")
	assert_near(plain.interactable.interaction_time_s, Tweak.interaction().item_pickup_s, 0.001, "plain hold time")
