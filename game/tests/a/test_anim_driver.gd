## D-041 / characters.md v1.3: AnimDriver picks humanoid clips from NPC / crew state (presentation only).
## Uses a small rig built in code (Node3D root + Skeleton3D with HandR/Socket + AnimationPlayer with a
## "humanoid" library of empty clips carrying the contract names).
extends TestCase

const LOOPED: Array[StringName] = [
	&"idle", &"idle_alert", &"walk", &"run", &"sprint", &"crouch_idle", &"crouch_walk", &"strafe_l", &"strafe_r",
	&"walk_back", &"aim_rifle", &"aim_pistol", &"kneel_cuffed", &"hands_up", &"cower", &"lie_down", &"tied",
	&"flee", &"phone_call", &"pager_answer", &"investigate_look", &"smoke", &"lean_wall", &"sit_chair",
	&"desk_type", &"browse", &"downed", &"tased", &"carry_bag_walk", &"interact_low", &"interact_mid",
	&"interact_high", &"shield_walk", &"dozer_walk",
]
const ONCE: Array[StringName] = [
	&"turn_l", &"turn_r", &"fire_rifle", &"fire_pistol", &"reload_rifle", &"reload_pistol", &"melee",
	&"death_front", &"death_back", &"hit_react", &"surrender", &"radio_call", &"throw_bag",
	&"kick_charge", &"kick_hit", &"shield_bang", &"heal_ally",
]
## HandL/Socket local transform of the test rig (shield grip).
const HANDL_SOCKET: Transform3D = Transform3D(Basis(Vector3.UP, 0.3), Vector3(-0.25, 1.1, -0.45))
const HINT_SCRIPT: String = "extends Node\nvar anim_hint: StringName = &\"idle\"\n"

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(1)


static func _test_rig() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "TestRig"
	var skel: Skeleton3D = Skeleton3D.new()
	skel.name = "Skeleton3D"
	skel.add_bone("root")
	skel.add_bone("hand.R")
	skel.add_bone("hand.L")
	root.add_child(skel)
	for side: String in ["R", "L"]:
		var hand: BoneAttachment3D = BoneAttachment3D.new()
		hand.name = "Hand" + side
		hand.bone_name = "hand." + side
		hand.override_pose = false
		skel.add_child(hand)
		var socket: Marker3D = Marker3D.new()
		socket.name = "Socket"
		if side == "L":
			socket.transform = HANDL_SOCKET
		hand.add_child(socket)
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib: AnimationLibrary = AnimationLibrary.new()
	for c: StringName in LOOPED + ONCE:
		var a: Animation = Animation.new()
		a.length = 1.0 if LOOPED.has(c) else 0.5
		a.loop_mode = Animation.LOOP_LINEAR if LOOPED.has(c) else Animation.LOOP_NONE
		lib.add_animation(c, a)
	ap.add_animation_library(AnimDriver.LIBRARY, lib)
	root.add_child(ap)
	return root


func _npc(role: StringName = &"guard", animated: bool = true, with_brain: bool = true) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = role
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	if animated:
		visual.add_child(_test_rig())
	else:
		var cap: MeshInstance3D = MeshInstance3D.new()
		cap.name = "Placeholder"
		cap.mesh = CapsuleMesh.new()
		visual.add_child(cap)
	npc.add_child(visual)
	if with_brain:
		var gs: GDScript = GDScript.new()
		gs.source_code = HINT_SCRIPT
		gs.reload()
		var brain: Node = Node.new()
		brain.name = "Brain"
		brain.set_script(gs)
		npc.add_child(brain)
	add_child(npc)
	_nodes.append(npc)
	return npc


func _drv(body: Node) -> AnimDriver:
	return AnimDriver.of(body)


func test_locomotion_clip_and_speed_scale() -> void:
	var npc: NpcBase = _npc()
	var d: AnimDriver = _drv(npc)
	assert_true(d != null and d.player != null, "driver created for an animated visual")
	assert_true(AnimDriver.drives(npc))
	var cases: Array = [
		[Vector3(0, 0, -1.6), &"walk", 1.0], [Vector3(0, 0, -3.5), &"run", 1.0],
		[Vector3(0, 0, -3.0), &"run", 3.0 / 3.5], [Vector3(0, 0, -5.75), &"sprint", 1.0],
		[Vector3(0, 0, -1.2), &"walk", 0.75], [Vector3(0, 0, 1.3), &"walk_back", 1.0],
		[Vector3(1.2, 0, 0), &"strafe_r", 1.0], [Vector3(-0.6, 0, 0), &"strafe_l", 0.5],
		[Vector3.ZERO, &"idle", 1.0],
	]
	for c: Array in cases:
		npc.velocity = c[0]
		d.tick(0.016)
		assert_eq(d.clip, c[1], "clip for v=%s" % c[0])
		assert_near(d.player.speed_scale, float(c[2]), 0.001, "speed_scale for v=%s" % c[0])
	npc.velocity = Vector3(0, 0, -1.6)
	d.tick(0.016)
	assert_eq(String(d.player.current_animation), "humanoid/walk", "played as humanoid/<clip>")
	var skel: Skeleton3D = d.rig.get_node(^"Skeleton3D") as Skeleton3D
	skel.motion_scale = 1.25
	npc.velocity = Vector3(0, 0, -2.0)
	d.tick(0.016)
	assert_near(d.player.speed_scale, 2.0 / (1.6 * 1.25), 0.001, "speed_scale divided by Skeleton3D.motion_scale")


func test_civilian_panic_flees() -> void:
	var civ: NpcBase = _npc(&"civilian")
	var d: AnimDriver = _drv(civ)
	civ.alert_state = Enums.AlertState.PANICKED
	civ.velocity = Vector3(0, 0, -4.0)
	d.tick(0.016)
	assert_eq(d.clip, &"flee")
	assert_near(d.player.speed_scale, 1.0, 0.001, "flee clip speed 4.0")


func test_anim_hint_mapping() -> void:
	var npc: NpcBase = _npc()
	var d: AnimDriver = _drv(npc)
	var brain: Node = npc.get_node(^"Brain")
	var cases: Array = [
		[&"smoke", &"smoke"], [&"phone", &"phone_call"], [&"radio_call", &"radio_call"],
		[&"investigate_look", &"investigate_look"], [&"check_door", &"investigate_look"],
		[&"pager_answer", &"pager_answer"], [&"idle_alert", &"idle_alert"], [&"aim_pistol", &"aim_pistol"],
		[&"aim", &"aim_pistol"], [&"cower", &"cower"], [&"hands_up", &"hands_up"], [&"tied", &"tied"],
		[&"kneel_cuffed", &"kneel_cuffed"], [&"down", &"lie_down"], [&"desk_work", &"desk_work"],
		[&"sit", &"sit_chair"], [&"lean", &"lean_wall"], [&"walk", &"idle"],
	]
	for c: Array in cases:
		brain.set(&"anim_hint", c[0])
		d.tick(0.016)
		assert_eq(d.clip, c[1], "hint %s" % c[0])
	brain.set(&"anim_hint", &"tied")
	npc.velocity = Vector3(0, 0, -1.6)
	d.tick(0.016)
	assert_eq(d.clip, &"tied", "pose hints win over locomotion")
	brain.set(&"anim_hint", &"smoke")
	d.tick(0.016)
	assert_eq(d.clip, &"walk", "idle hints yield to locomotion")
	var cop: NpcBase = _npc(&"police")
	cop.get_node(^"Brain").set(&"anim_hint", &"aim")
	_drv(cop).tick(0.016)
	assert_eq(_drv(cop).clip, &"aim_rifle", "police without a WeaponDef aim rifles (AnimTweak role map)")


func test_alert_state_fallbacks_without_brain() -> void:
	var npc: NpcBase = _npc(&"guard", true, false)
	var d: AnimDriver = _drv(npc)
	d.tick(0.016)
	assert_eq(d.clip, &"idle")
	npc.alert_state = Enums.AlertState.ALARMED
	d.tick(0.016)
	assert_eq(d.clip, &"idle_alert", "alerted idle")
	npc.alert_state = Enums.AlertState.TIED
	d.tick(0.016)
	assert_eq(d.clip, &"tied")
	npc.alert_state = Enums.AlertState.INTIMIDATED
	d.tick(0.016)
	assert_eq(d.clip, &"hands_up")


func test_death_clip_from_hit_direction() -> void:
	var a: NpcBase = _npc()
	var b: NpcBase = _npc()
	# Facing -Z (identity). A bullet travelling -Z hit A from behind; one travelling +Z hit B from the front.
	a.die({"direction": Vector3(0, 0, -1)})
	a.last_damage = {"direction": Vector3(0, 0, -1)}
	b.last_damage = {"direction": Vector3(0, 0, 1)}
	b.die({"direction": Vector3(0, 0, 1)})
	_drv(a).tick(0.016)
	_drv(b).tick(0.016)
	assert_eq(_drv(a).clip, &"death_front", "hit from behind: face down")
	assert_eq(_drv(b).clip, &"death_back", "hit from the front: onto the back")
	assert_eq(a.visual_root.rotation, Vector3.ZERO, "animated corpse is not tipped over like the capsule")
	_drv(a).tick(0.5)
	assert_eq(_drv(a).clip, &"death_front", "death clip holds")


func test_noop_on_capsule_visual() -> void:
	var npc: NpcBase = _npc(&"guard", false)
	assert_true(AnimDriver.of(npc) == null, "no driver for the capsule placeholder")
	assert_false(AnimDriver.drives(npc))
	var d: AnimDriver = AnimDriver.new()
	d.name = AnimDriver.NODE_NAME
	npc.add_child(d)
	assert_true(d.player == null, "a driver on a capsule stays inactive")
	npc.velocity = Vector3(0, 0, -2.0)
	d.tick(0.016)
	assert_eq(d.clip, &"", "nothing played")
	npc.die({})
	assert_near(npc.visual_root.rotation.x, -PI * 0.5, 0.001, "capsule corpse still tips over")


func test_turn_in_place() -> void:
	var npc: NpcBase = _npc()
	var d: AnimDriver = _drv(npc)
	d.tick(0.016)
	npc.rotation.y = deg_to_rad(90.0)
	d.tick(0.016)
	assert_eq(d.clip, &"turn_l", "idle yaw change > 60 deg plays turn_l")
	assert_true(d.rig.rotation.y < deg_to_rad(-80.0), "rig counter-rotated (still facing the old way)")
	for _i: int in 50:
		d.tick(0.016)
	assert_near(d.rig.rotation.y, 0.0, 0.01, "rig caught up with the body after the turn (90 deg / 0.8 s)")
	npc.rotation.y = 0.0
	d.tick(0.016)
	assert_eq(d.clip, &"turn_r", "turning back right plays turn_r")


func test_fire_oneshot_and_return() -> void:
	var npc: NpcBase = _npc()
	npc.net_id = 987654
	var d: AnimDriver = _drv(npc)
	npc.get_node(^"Brain").set(&"anim_hint", &"aim_pistol")
	d.tick(0.016)
	EventBus.weapon_fired.emit(npc.net_id, &"weapon.npc_pistol", false, Vector3.ZERO)
	d.tick(0.016)
	assert_eq(d.clip, &"fire_pistol", "shot plays fire_pistol")
	d.tick(0.6)
	assert_eq(d.clip, &"aim_pistol", "back to the aim pose")


func test_crew_states_and_crouch() -> void:
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	crew.setup(0, {"peer_id": 0, "is_ai": true, "display_name": "Bot"}, null)
	var visual: Node3D = crew.get_node(^"Visual") as Node3D
	for c: Node in visual.get_children():
		c.free()
	visual.add_child(_test_rig())
	add_child(crew)
	_nodes.append(crew)
	await wait_frames(2)  # CrewView.refresh is deferred
	var d: AnimDriver = _drv(crew)
	assert_true(d != null and d.player != null, "AI crew body gets a driver")
	d.tick(0.016)
	assert_eq(d.clip, &"idle", "unmasked idle")
	crew.masked = true
	d.tick(0.016)
	assert_eq(d.clip, &"idle_alert", "masked idle")
	crew.crouched = true
	crew.velocity = Vector3(0, 0, -1.5)
	d.tick(0.016)
	assert_eq(d.clip, &"crouch_walk")
	assert_near(d.player.speed_scale, 1.0, 0.001)
	crew.crouched = false
	crew.sprinting = true
	crew.velocity = Vector3(0, 0, -5.75)
	d.tick(0.016)
	assert_eq(d.clip, &"sprint")
	crew.sprinting = false
	crew.velocity = Vector3.ZERO
	crew.crew_state = Enums.CrewState.DOWNED
	d.tick(0.016)
	assert_eq(d.clip, &"downed")
	crew.crew_state = Enums.CrewState.NORMAL
	var def: WeaponDef = ContentDB.weapon(crew.weapons.weapon_id(crew.weapons.equipped_slot))
	if def != null and def.model != null:
		assert_true(d.weapon_visual != null and d.weapon_visual.get_parent().name == "Socket", "weapon at HandR/Socket")


func test_assembled_fixture_when_present() -> void:
	var path: String = "res://world/characters/_test/body_base.tscn"
	if not ResourceLoader.exists(path):
		skip("ENV D fixture body_base not assembled")
		return
	var npc: NpcBase = NpcBase.new()
	npc.visual_scene = load(path) as PackedScene
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	npc.add_child(visual)
	add_child(npc)
	_nodes.append(npc)
	var d: AnimDriver = _drv(npc)
	if d == null or not d.player.has_animation("humanoid/walk"):
		skip("fixture has no humanoid clips yet")
		return
	npc.velocity = Vector3(0, 0, -1.6)
	d.tick(0.016)
	assert_eq(String(d.player.current_animation), "humanoid/walk", "real contract visual plays humanoid/walk")


func _special(walk_clip: String) -> NpcBase:
	var npc: NpcBase = _npc(&"special")
	var def: EnemyDef = EnemyDef.new()
	def.move_speed = 3.5
	def.params = {"anim_walk_clip": walk_clip, "advance_speed": 1.8}
	npc.enemy_def = def
	return npc


## Lead ruling (PD2): Bulwarks / Wreckers walk with their own clip; never a walk clip above speed_scale_max.
func test_special_walk_clips() -> void:
	var tw: AnimTweak = AnimTweak.data()
	assert_near(float(tw.clip_speeds.get(&"shield_walk", 0.0)), 1.6, 0.001, "shield_walk clip speed")
	assert_near(float(tw.clip_speeds.get(&"dozer_walk", 0.0)), 1.6, 0.001, "dozer_walk clip speed")
	var bw: NpcBase = _special("shield_walk")
	var d: AnimDriver = _drv(bw)
	for v: float in [1.8, 1.2, 2.0]:
		bw.velocity = Vector3(0, 0, -v)
		d.tick(0.016)
		assert_eq(d.clip, &"shield_walk", "Bulwark walking at %.1f plays shield_walk" % v)
		assert_near(d.player.speed_scale, v / 1.6, 0.001, "speed_scale = v / 1.6")
	bw.velocity = Vector3(0.9, 0, 0)
	d.tick(0.016)
	assert_eq(d.clip, &"shield_walk", "sideways shuffle keeps the shield walk")
	bw.velocity = Vector3(0, 0, -3.2)
	d.tick(0.016)
	assert_eq(d.clip, &"run", "repositioning at run speed plays run, not a sped-up walk")
	assert_true(d.player.speed_scale <= tw.speed_scale_max)
	var wr: NpcBase = _special("dozer_walk")
	var dw: AnimDriver = _drv(wr)
	wr.velocity = Vector3(0, 0, -1.8)
	dw.tick(0.016)
	assert_eq(dw.clip, &"dozer_walk", "Wrecker plays dozer_walk")
	assert_near(dw.player.speed_scale, 1.8 / 1.6, 0.001)
	wr.velocity = Vector3(0, 0, -3.5)
	dw.tick(0.016)
	assert_eq(dw.clip, &"run", "Wrecker above the walk threshold runs")
	var cop: NpcBase = _npc(&"police")
	cop.velocity = Vector3(0, 0, -1.8)
	_drv(cop).tick(0.016)
	assert_eq(_drv(cop).clip, &"walk", "units without anim_walk_clip keep walk")


func test_special_action_hints() -> void:
	var ph: NpcBase = _npc(&"special")
	var d: AnimDriver = _drv(ph)
	var brain: Node = ph.get_node(^"Brain")
	brain.set(&"anim_hint", &"kick_charge")
	d.tick(0.016)
	assert_eq(d.clip, &"kick_charge", "Phantom windup plays kick_charge")
	brain.set(&"anim_hint", &"sprint")
	ph.velocity = Vector3(0, 0, -6.0)
	d.tick(0.016)
	assert_eq(d.clip, &"sprint", "the charge sprints")
	brain.set(&"anim_hint", &"kick_hit")
	ph.velocity = Vector3.ZERO
	d.tick(0.016)
	assert_eq(d.clip, &"kick_hit", "the kick plays kick_hit")
	d.tick(0.6)
	assert_ne(d.clip, &"kick_hit", "kick_hit plays once")
	var bw: NpcBase = _special("shield_walk")
	var db: AnimDriver = _drv(bw)
	var bb: Node = bw.get_node(^"Brain")
	bb.set(&"anim_hint", &"aim")
	db.tick(0.016)
	assert_eq(db.clip, &"aim_rifle", "holding Bulwark aims")
	bb.set(&"anim_hint", &"shield_bang")
	db.tick(0.016)
	assert_eq(db.clip, &"shield_bang", "Bulwark bang plays shield_bang (over the aim pose)")
	var md: NpcBase = _npc(&"special")
	md.get_node(^"Brain").set(&"anim_hint", &"heal_ally")
	_drv(md).tick(0.016)
	assert_eq(_drv(md).clip, &"heal_ally", "Corpsman heal plays heal_ally")


## characters.md: the shield grip is HandL/Socket (socket -Z = shield face); with no skeleton the offset stays.
func test_bulwark_shield_follows_handl_socket() -> void:
	var tw: HeavySpecialTweak = HeavySpecialTweak.data()
	var bw: NpcBase = _special("shield_walk")
	var shield: BulwarkShield = tw.bulwark_shield_scene.instantiate() as BulwarkShield
	shield.attach_to(bw, tw.bulwark_shield_offset)
	var socket: Node3D = AnimDriver.socket_of(bw, "HandL")
	assert_true(socket != null and shield.grip_socket == socket, "grip socket found on the visual")
	assert_true(shield.global_transform.is_equal_approx(socket.global_transform), "aligned to HandL/Socket")
	assert_true(shield.get_parent() == bw and shield.get_node_or_null("Collision") != null, "still a carried body")
	bw.global_position = Vector3(3, 0, 1)
	shield.follow_grip(0.016)
	assert_true(shield.global_transform.origin.is_equal_approx(socket.global_transform.origin), "follows the carrier")
	shield.set_guard(false, tw.bulwark_stagger_shield_offset)
	assert_false(shield.follow_grip(0.016), "lowered guard keeps the stagger offset")
	var cap: NpcBase = _npc(&"special", false)
	var s2: BulwarkShield = tw.bulwark_shield_scene.instantiate() as BulwarkShield
	s2.attach_to(cap, tw.bulwark_shield_offset)
	assert_true(s2.grip_socket == null, "capsule placeholder: no socket")
	assert_true(s2.position.is_equal_approx(tw.bulwark_shield_offset), "capsule placeholder: offset kept")


## Lead ruling (PD2): heavy specials advance at a walk (<= 2.0 m/s), run speed only to reposition.
func test_heavy_brains_advance_walking() -> void:
	for id: String in ["bulwark", "wrecker", "wrecker_b", "wrecker_g", "wrecker_m", "wrecker_s"]:
		var def: EnemyDef = ACombatSpecials.def(id)
		var npc: NpcBase = NpcBase.new()
		npc.enemy_def = def
		for m: StringName in [&"approach", &"cover", &"back_off", &"shield_follow"]:
			var sp: float = PoliceSpecialKit.heavy_move_speed(npc, m, def.move_speed)
			assert_true(sp >= 1.6 and sp <= 2.0, "%s advances (%s) at a walk: %.2f" % [id, m, sp])
		assert_near(PoliceSpecialKit.heavy_move_speed(npc, &"order", def.move_speed), def.move_speed, 0.001,
			"%s repositions at run speed" % id)
		npc.free()
	var rt: HeistRuntime = await ACombatSpecials.launch(self)
	var c: CrewController = await ACombatSpecials.place_crew(rt, 0, Vector3(0, 0.05, 0))
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	rt.stealth.raise_alarm(&"test", 0)
	var units: Array[NpcBase] = [
		ACombatSpecials.spawn(rt, "bulwark", Vector3(4, 0.05, -18), Vector3(0, 0, 1)),
		ACombatSpecials.spawn(rt, "wrecker", Vector3(-4, 0.05, -18), Vector3(0, 0, 1)),
	]
	var max_v: Array[float] = [0.0, 0.0]
	var moved: Array[bool] = [false, false]
	for _i: int in 150:
		await wait_physics_frames(1)
		for k: int in units.size():
			var u: NpcBase = units[k]
			var b: PoliceBrain = u.get_node("Brain") as PoliceBrain
			if not HeavySpecialTweak.data().heavy_run_modes.has(b.mode):
				var hv: float = Vector2(u.velocity.x, u.velocity.z).length()
				max_v[k] = maxf(max_v[k], hv)
				moved[k] = moved[k] or hv > 1.0
	for k: int in units.size():
		assert_true(moved[k], "%s advanced" % units[k].enemy_def.id)
		assert_true(max_v[k] <= 2.0 + 0.05, "%s advances at <= 2.0 m/s (max %.2f)" % [units[k].enemy_def.id, max_v[k]])
	assert_true(c != null)
	Modifiers.clear_all()
	rt.teardown()
	await wait_frames(2)


## D-069 ambient substitutions (characters.md v1.7): cleaners mop, Kessler reads in bed, seated phone calls,
## the camera operator watches monitors, cartel gunmen idle as thugs; mug_walk walks at v / 1.3.
func test_d069_ambient_hint_substitutions() -> void:
	var civ: NpcBase = _npc(&"civilian")
	var d: AnimDriver = _drv(civ)
	var brain: Node = civ.get_node(^"Brain")
	civ.spawn_info = {"tags": [&"civ_cleaner_l41", &"civ_staff"]}
	brain.set(&"anim_hint", &"browse")
	assert_eq(d._hint(), &"mop", "cleaner browse -> mop")
	civ.spawn_info = {"tags": [&"civ_kessler"]}
	brain.set(&"anim_hint", &"sit")
	assert_eq(d._hint(), &"sit_bed_read", "Kessler sit -> sit_bed_read")
	civ.spawn_info = {"tags": [], "idle_activity": &"sit"}
	brain.set(&"anim_hint", &"phone")
	assert_eq(d._hint(), &"phone_seated", "seated phone call")
	civ.spawn_info = {"tags": []}
	brain.set(&"anim_hint", &"browse")
	assert_eq(d._hint(), &"browse", "others browse")
	var op: NpcBase = _npc(&"guard")
	op.spawn_info = {"tags": [], "no_patrol": true}
	op.get_node(^"Brain").set(&"anim_hint", &"idle")
	assert_eq(_drv(op)._hint(), &"sit_chair_watch", "camera operator at the monitors")
	var gang: NpcBase = _npc(CartelBrain.ROLE)
	gang.get_node(^"Brain").set(&"anim_hint", &"idle")
	assert_eq(_drv(gang)._hint(), &"idle_thug", "cartel idle")
	assert_eq(AnimDriver.HINT_CLIPS[&"mug"], &"mug_idle")
	assert_near(float(AnimTweak.data().clip_speeds[&"mug_carry_walk"]), 1.3, 0.001, "mug walk speed_scale = v / 1.3")
