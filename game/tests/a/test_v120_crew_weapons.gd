## characters.md v1.20 (D-116, ENV D 70856c53): hold kinds per weapon class (rifle / smg / sniper / lmg / pistol /
## akimbo), the third-person akimbo pair one gun per hand, the *_armed interaction clips for a crew body holding a
## weapon, and the carried-bag visual at Back/Socket while carrying (removed on drop / throw). Real cast rig (rook);
## a sub-case whose clip the rig lacks is skipped with a print.
extends TestCase

const HEISTER: StringName = &"rook"
const AKIMBO_ID: StringName = &"weapon.akimbo_warden_45"
const KINDS: Array[StringName] = [&"rifle", &"smg", &"sniper", &"lmg", &"pistol", &"akimbo"]

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


func _bot(loadout: Loadout = null) -> CrewController:
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	crew.setup(0, {"peer_id": 0, "is_ai": true, "display_name": "Bot"}, loadout)
	crew.heister = HEISTER
	add_child(crew)
	_nodes.append(crew)
	await wait_frames(3)  # CrewView.refresh is deferred
	return crew


func _has(d: AnimDriver, c: StringName) -> bool:
	return d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, c])


func _missing(d: AnimDriver, clips: Array[StringName], what: String) -> bool:
	if d == null or d.player == null:
		print("[v120] skip %s: the crew body has no animated rig" % what)
		return true
	for c: StringName in clips:
		if not _has(d, c):
			print("[v120] skip %s: the rig has no %s (ENV D assets not checked out)" % [what, c])
			return true
	return false


func _def(cls: Enums.WeaponClass, akimbo: bool = false) -> WeaponDef:
	var w: WeaponDef = WeaponDef.new()
	w.weapon_class = cls
	w.akimbo = akimbo
	return w


func test_kind_per_weapon_class() -> void:
	var crew: CrewController = await _bot()
	var d: AnimDriver = AnimDriver.of(crew)
	assert_true(d != null, "bot has a driver")
	var cases: Array = [
		[Enums.WeaponClass.ASSAULT_RIFLE, false, &"rifle"], [Enums.WeaponClass.SHOTGUN, false, &"rifle"],
		[Enums.WeaponClass.SMG, false, &"smg"], [Enums.WeaponClass.SPECIAL, false, &"smg"],
		[Enums.WeaponClass.SNIPER, false, &"sniper"], [Enums.WeaponClass.LMG, false, &"lmg"],
		[Enums.WeaponClass.PISTOL, false, &"pistol"], [Enums.WeaponClass.PISTOL, true, &"akimbo"],
	]
	for c: Array in cases:
		var k: StringName = d._kind_for(_def(c[0], c[1]))
		assert_eq(k, c[2], "class %d akimbo %s -> %s" % [c[0], c[1], c[2]])
		d.weapon_kind = k
		assert_eq(d.aim_family(), &"pistol" if c[2] in [&"pistol", &"akimbo"] else &"rifle", "%s aims as" % k)
	if _missing(d, [&"idle_alert_smg"], "idle per kind"):
		return
	d.set_process(false)
	crew.masked = true
	for k: StringName in KINDS:
		if _missing(d, [StringName("idle_alert_" + k), StringName("hold_" + k)], "kind %s" % k):
			continue
		d.weapon_kind = k
		crew.velocity = Vector3.ZERO
		for _i: int in 3:
			d.tick(0.05)
		assert_eq(d.clip, StringName("idle_alert_" + k), "%s: idle_alert_%s" % [k, k])
		crew.velocity = Vector3(0, 0, -1.6)
		for _i: int in 8:
			d.tick(0.05)
		assert_eq(d.hold_layer.clip, HoldGait.clip_for(StringName("hold_" + k), d.clip, d.player, AnimDriver.LIBRARY),
			"%s: hold_%s (gait-locked, v1.25) over the walk" % [k, k])
		crew.velocity = Vector3.ZERO
		for _i: int in 20:
			d.tick(0.05)


func test_akimbo_one_gun_per_hand() -> void:
	if ContentDB.weapon(AKIMBO_ID) == null:
		print("[v120] skip akimbo: no %s" % AKIMBO_ID)
		return
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.secondary = AKIMBO_ID
	l.secondary_mods = [] as Array[StringName]
	var crew: CrewController = await _bot(l)
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [&"idle_alert_akimbo"], "akimbo"):
		return
	crew.weapons.equip(Enums.WeaponSlot.SECONDARY)
	await wait_frames(2)
	d.refresh_weapon()
	assert_eq(d.weapon_kind, &"akimbo", "an akimbo pair is the akimbo kind")
	var wv: WeaponVisual = d.weapon_visual as WeaponVisual
	assert_true(wv != null and wv.is_akimbo(), "the pair's WeaponVisual")
	var hand_r: Node3D = d.rig.get_node("Skeleton3D/HandR/Socket") as Node3D
	var hand_l: Node3D = d.rig.get_node("Skeleton3D/HandL/Socket") as Node3D
	assert_true(wv.get_parent() == hand_r, "first gun at HandR/Socket")
	assert_true(d.weapon_offhand != null and d.weapon_offhand.get_parent() == hand_l, "second gun at HandL/Socket")
	assert_true(d.weapon_offhand.transform.is_equal_approx(Transform3D.IDENTITY), "on the socket (grip convention)")
	var guns_r: int = 0
	for c: Node in wv.get_children():
		if c is Node3D and c.find_child("Slide", true, false) != null:
			guns_r += 1
	assert_eq(guns_r, 1, "one gun in the right hand (not the pair)")
	assert_eq(hand_l.find_children("Slide", "", true, false).size(), 1, "one gun in the left hand")
	d.refresh_weapon()
	assert_eq(hand_l.get_child_count(), 1, "refresh replaces the offhand gun (no stacking)")


func test_armed_interaction_clips() -> void:
	var crew: CrewController = await _bot()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [&"interact_low_armed", &"interact_mid_armed", &"interact_high_armed", &"throw_bag_armed"],
			"armed interactions"):
		return
	assert_true(d._holds_weapon, "the bot holds a weapon")
	d.set_process(false)
	EventBus.interaction_started.emit(0, crew.slot, &"use")
	for h: Array in [[0.3, &"interact_low"], [1.0, &"interact_mid"], [1.9, &"interact_high"]]:
		d._interact_height = h[0]
		d.tick(0.016)
		assert_eq(d.clip, StringName(String(h[1]) + "_armed"), "armed, height %.1f" % h[0])
	d._holds_weapon = false
	d.tick(0.016)
	assert_eq(d.clip, &"interact_high", "unarmed: the shared clip")
	d._holds_weapon = true
	EventBus.interaction_cancelled.emit(0, crew.slot)
	EventBus.loot_dropped.emit(0, crew.slot, true)
	d.tick(0.016)
	assert_eq(d.clip, &"throw_bag_armed", "armed throw")
	d._holds_weapon = false
	EventBus.loot_dropped.emit(0, crew.slot, true)
	d.tick(0.016)
	assert_eq(d.clip, &"throw_bag", "unarmed throw")


func test_carried_bag_visual_on_back() -> void:
	var crew: CrewController = await _bot()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [&"carry_bag_walk"], "carried bag"):
		return
	var bag: LootBag = LootBag.new()
	bag.loot_id = &"loot.bearer_bonds"
	var vis: Node3D = Node3D.new()
	vis.name = "Visual"
	bag.add_child(vis)
	add_child(bag)
	_nodes.append(bag)
	await wait_frames(1)
	d.set_process(false)
	crew.set_carried_bag(bag)
	crew.velocity = Vector3(0, 0, -1.6)
	for _i: int in 20:
		d.tick(0.05)  # past walk_start
	var back: Node3D = d.rig.get_node("Skeleton3D/Back/Socket") as Node3D
	assert_eq(d.clip, &"carry_bag_walk", "carrying: carry_bag_walk")
	assert_true(d.bag_visual != null and d.bag_visual.get_parent() == back, "bag visual at Back/Socket")
	assert_eq(String(d.bag_visual.name), AnimDriver.CARRIED_BAG_NODE, "named CarriedBag")
	var def: LootDef = ContentDB.loot(bag.loot_id)
	if def != null and def.bag_model != null:
		assert_eq(d.bag_visual.scene_file_path, def.bag_model.resource_path, "the LootDef's bag_model")
	assert_false(bag.visual_root.visible, "the LootBag's own visual is hidden while on the back")
	d.tick(0.05)
	assert_eq(back.find_children(AnimDriver.CARRIED_BAG_NODE, "", false, false).size(), 1, "one bag, not stacked")
	crew.set_carried_bag(null)  # dropped / thrown
	d.tick(0.05)
	assert_true(d.bag_visual == null, "dropped: the back visual is gone")
	await wait_frames(1)
	assert_eq(back.find_children(AnimDriver.CARRIED_BAG_NODE, "", false, false).size(), 0, "freed")
	assert_true(bag.visual_root.visible, "the LootBag shows its own visual again")
	# characters.md v1.22: Back/Socket is the bag pivot; only a per-weight lift along the socket's Y.
	var lift: Dictionary = AnimTweak.data().carried_bag_offset_by_weight
	for w: int in [Enums.LootWeight.LIGHT, Enums.LootWeight.MEDIUM, Enums.LootWeight.HEAVY, Enums.LootWeight.VERY_HEAVY]:
		bag.weight = w as Enums.LootWeight
		crew.set_carried_bag(bag)
		d.tick(0.05)
		assert_true(d.bag_visual != null, "weight %d: on the back" % w)
		if d.bag_visual != null:
			assert_true(d.bag_visual.transform.basis.is_equal_approx(Basis.IDENTITY), "weight %d: no rotation" % w)
			assert_true(d.bag_visual.position.is_equal_approx(lift[w] as Vector3), "weight %d: %s" % [w, lift[w]])
		crew.set_carried_bag(null)
		d.tick(0.05)
	assert_true((lift[Enums.LootWeight.MEDIUM] as Vector3).is_zero_approx(), "a MEDIUM bag sits at the pivot")
	assert_near((lift[Enums.LootWeight.LIGHT] as Vector3).y, 0.05, 0.0001, "light rides 5 cm up")
	assert_near((lift[Enums.LootWeight.HEAVY] as Vector3).y, -0.05, 0.0001, "heavy 5 cm down")
