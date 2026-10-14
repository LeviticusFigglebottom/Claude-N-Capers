# gdlint:disable=max-public-methods
## D-041 / characters.md v1.3: AnimDriver picks humanoid clips from NPC / crew state (presentation only).
## Uses a small rig built in code (Node3D root + Skeleton3D with HandR/Socket + AnimationPlayer with a
## "humanoid" library of empty clips carrying the contract names).
extends TestCase

const LOOPED: Array[StringName] = [
	&"idle", &"idle_alert", &"walk", &"run", &"sprint", &"crouch_idle", &"crouch_walk", &"strafe_l", &"strafe_r",
	&"walk_back", &"aim_rifle", &"aim_pistol", &"kneel_cuffed", &"hands_up", &"cower", &"lie_down", &"tied",
	&"flee", &"phone_call", &"pager_answer", &"investigate_look", &"smoke", &"lean_wall", &"sit_chair",
	&"desk_type", &"browse", &"downed", &"tased", &"carry_bag_walk", &"interact_low", &"interact_mid",
	&"interact_high", &"shield_walk", &"dozer_walk", &"walk_fl", &"walk_fr", &"walk_bl", &"walk_br", &"run_fl",
	&"run_fr", &"run_bl", &"run_br",
]
const ONCE: Array[StringName] = [
	&"turn_l", &"turn_r", &"fire_rifle", &"fire_pistol", &"reload_rifle", &"reload_pistol", &"melee",
	&"death_front", &"death_back", &"hit_react", &"surrender", &"radio_call", &"throw_bag",
	&"kick_charge", &"kick_hit", &"shield_bang", &"heal_ally", &"death_seated_slump", &"death_seated_fall",
	&"hit_react_back", &"hit_react_left", &"hit_react_right", &"death_side", &"death_front_b", &"death_back_b",
]
## v1.10 starts / stops: only the start/stop test's rig carries them (the other tests read the plain locomotion).
const START_STOP: Array[StringName] = [&"walk_start", &"walk_stop", &"run_start", &"run_stop"]
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
	assert_true(_drv(a).clip in [&"death_front", &"death_front_b"], "hit from behind: face down (%s)" % _drv(a).clip)
	assert_true(_drv(b).clip in [&"death_back", &"death_back_b"], "hit from the front: onto the back (%s)" % _drv(b).clip)
	assert_eq(a.visual_root.rotation, Vector3.ZERO, "animated corpse is not tipped over like the capsule")
	_drv(a).tick(0.5)
	assert_true(_drv(a).clip in [&"death_front", &"death_front_b"], "death clip holds")


## characters.md v1.11 (PO-pass #6, the corpse through the GH desk): an NPC killed while seated (desk_work,
## phone_seated, sit_chair_watch, cower_seated) slumps on the desk from a frontal or melee kill and falls off the chair
## otherwise; without the clips it falls back to death_front / death_back.
func test_seated_deaths() -> void:
	var cases: Array = [
		# [hint, direction, damage type, expected]
		[&"desk_work", Vector3(0, 0, 1), Enums.DamageType.BULLET, &"death_seated_slump"],
		[&"phone_seated", Vector3(0, 0, -1), Enums.DamageType.BULLET, &"death_seated_fall"],
		[&"cower_seated", Vector3(0, 0, -1), Enums.DamageType.MELEE, &"death_seated_slump"],
		[&"browse", Vector3(0, 0, 1), Enums.DamageType.BULLET, &"death_back"],
	]
	for c: Array in cases:
		var npc: NpcBase = _npc(&"civilian")
		npc.get_node("Brain").set(&"anim_hint", c[0])
		_drv(npc).tick(0.016)
		npc.last_damage = {"direction": c[1], "type": c[2]}
		npc.die({"direction": c[1]})
		_drv(npc).tick(0.016)
		assert_eq(_drv(npc).clip, c[3], "%s, hit %s, type %d" % [c[0], c[1], c[2]])
	var old: NpcBase = _npc(&"civilian")
	var lib: AnimationLibrary = _drv(old).player.get_animation_library(AnimDriver.LIBRARY)
	lib.remove_animation(&"death_seated_fall")
	old.get_node("Brain").set(&"anim_hint", &"desk_work")
	_drv(old).tick(0.016)
	old.last_damage = {"direction": Vector3(0, 0, -1), "type": Enums.DamageType.BULLET}
	old.die({"direction": Vector3(0, 0, -1)})
	_drv(old).tick(0.016)
	assert_true(_drv(old).clip in [&"death_front", &"death_front_b"], "no seated clip in the library: the standing death")


## v1.10 (D-111 "almost zero animations play"): non-lethal damage plays a hit react picked by where the bullet
## came from (front / back / left / right), spaced hit_react_min_gap_s apart; a dead body never flinches.
func test_hit_reacts_from_damage_direction() -> void:
	var npc: NpcBase = _npc()
	npc.net_id = 70001
	var d: AnimDriver = _drv(npc)
	# Facing -Z. Bullet travel: +Z came from the front, -Z from behind, +X from the left, -X from the right.
	var cases: Array = [[Vector3(0, 0, 1), &"hit_react"], [Vector3(0, 0, -1), &"hit_react_back"],
		[Vector3(1, 0, 0), &"hit_react_left"], [Vector3(-1, 0, 0), &"hit_react_right"]]
	for c: Array in cases:
		d._last_hit_react_t = -100.0
		EventBus.damage_applied.emit(npc.net_id, 0, {"direction": c[0], "amount": 12.0, "killed": false})
		d.tick(0.016)
		assert_eq(d.clip, c[1], "hit from travel %s" % c[0])
	d._last_hit_react_t = -100.0
	EventBus.damage_applied.emit(npc.net_id, 0, {"direction": Vector3(0, 0, 1), "amount": 12.0, "killed": false})
	var first: float = d._last_hit_react_t
	EventBus.damage_applied.emit(npc.net_id, 0, {"direction": Vector3(0, 0, -1), "amount": 12.0, "killed": false})
	assert_eq(d._last_hit_react_t, first, "a second hit inside the gap does not restart the react")
	EventBus.damage_applied.emit(npc.net_id + 1, 0, {"direction": Vector3(1, 0, 0), "amount": 12.0, "killed": false})
	assert_eq(d._last_hit_react_t, first, "someone else's damage is ignored")


## The server path: NpcBase.take_hit (non-lethal) reaches the driver through damage_applied.
func test_take_hit_triggers_a_hit_react() -> void:
	var npc: NpcBase = _npc()
	npc.net_id = 70011
	npc.max_health = 200.0
	npc.health = 200.0
	var d: AnimDriver = _drv(npc)
	npc.take_hit({"amount": 10.0, "direction": Vector3(0, 0, -1), "type": Enums.DamageType.BULLET})
	d.tick(0.016)
	assert_true(npc.alive, "non-lethal")
	assert_eq(d.clip, &"hit_react_back", "hit from behind")


## v1.10 death variety: a strong side hit falls sideways; front / back deaths use the _b variant for half of the
## bodies (stable per node name, so every peer agrees).
func test_death_variety() -> void:
	var side: NpcBase = _npc()
	side.last_damage = {"direction": Vector3(1, 0, 0)}
	side.die({"direction": Vector3(1, 0, 0)})
	_drv(side).tick(0.016)
	assert_eq(_drv(side).clip, &"death_side", "side hit")
	var seen: Dictionary = {}
	for i: int in range(12):
		var n: NpcBase = _npc()
		n.name = "Npc_variety_%d" % i
		n.last_damage = {"direction": Vector3(0, 0, -1)}
		n.die({"direction": Vector3(0, 0, -1)})
		_drv(n).tick(0.016)
		seen[_drv(n).clip] = true
	assert_true(seen.has(&"death_front") and seen.has(&"death_front_b"), "both front deaths appear (%s)" % [seen.keys()])


## v1.10 starts / stops: setting off straight ahead plays walk_start / run_start over the locomotion, stopping out of
## a straight walk / run plays walk_stop / run_stop; sideways moves and libraries without the clips get neither.
func test_walk_run_start_and_stop() -> void:
	var npc: NpcBase = _npc()
	var d: AnimDriver = _drv(npc)
	var lib: AnimationLibrary = d.player.get_animation_library(AnimDriver.LIBRARY)
	for n: StringName in START_STOP:
		var a: Animation = Animation.new()
		a.length = 0.4
		lib.add_animation(n, a)
	d.tick(0.016)
	assert_eq(d.clip, &"idle", "standing")
	npc.velocity = Vector3(0, 0, -1.6)
	d.tick(0.016)
	assert_eq(d.clip, &"walk_start", "sets off: walk_start")
	d.tick(0.5)
	assert_eq(d.clip, &"walk", "then the walk cycle")
	npc.velocity = Vector3.ZERO
	d.tick(0.016)
	assert_eq(d.clip, &"walk_stop", "stops: walk_stop")
	d.tick(0.5)
	assert_eq(d.clip, &"idle", "then idle")
	npc.velocity = Vector3(0, 0, -3.5)
	d.tick(0.016)
	assert_eq(d.clip, &"run_start", "sets off running: run_start")
	d.tick(0.5)
	npc.velocity = Vector3.ZERO
	d.tick(0.016)
	assert_eq(d.clip, &"run_stop", "stops running: run_stop")
	d.tick(0.5)
	npc.velocity = Vector3(1.2, 0, 0)
	d.tick(0.016)
	assert_eq(d.clip, &"strafe_r", "a sideways move gets no start")


## v1.10 8-way locomotion: the four diagonals at walk and run speed (straight lines keep the 4-way clips).
func test_eight_way_locomotion() -> void:
	var npc: NpcBase = _npc()
	var d: AnimDriver = _drv(npc)
	var k: float = sqrt(0.5)
	var cases: Array = [
		[Vector3(k, 0, -k) * 1.6, &"walk_fr"], [Vector3(-k, 0, -k) * 1.6, &"walk_fl"],
		[Vector3(k, 0, k) * 1.3, &"walk_br"], [Vector3(-k, 0, k) * 1.3, &"walk_bl"],
		[Vector3(k, 0, -k) * 3.5, &"run_fr"], [Vector3(-k, 0, k) * 3.5, &"run_bl"],
		[Vector3(3.5, 0, 0), &"run_r"], [Vector3(0, 0, -1.6), &"walk"], [Vector3(0, 0, -3.5), &"run"],
	]
	for c: Array in cases:
		npc.velocity = c[0]
		d.tick(0.016)
		assert_eq(d.clip, c[1], "v=%s" % c[0])
	npc.velocity = Vector3(k, 0, -k) * 1.6
	d.tick(0.016)
	assert_near(d.player.speed_scale, 1.0, 0.01, "walk_fr runs at walk speed (1.6 m/s)")


## D-111: an NPC reload (NpcGunner's replicated reload cue) plays reload_rifle / reload_pistol on the NPC.
func test_npc_reload_cue_plays_the_reload_clip() -> void:
	var npc: NpcBase = _npc(&"police")
	npc.net_id = 70021
	var d: AnimDriver = _drv(npc)
	EventBus.audio_cue_requested.emit(NpcGunner.CUE_RELOAD_RIFLE, Vector3.ZERO, npc.net_id)
	d.tick(0.016)
	assert_eq(d.clip, &"reload_rifle", "rifle reload")
	d.tick(5.0)
	EventBus.audio_cue_requested.emit(NpcGunner.CUE_RELOAD_PISTOL, Vector3.ZERO, npc.net_id)
	d.tick(0.016)
	assert_eq(d.clip, &"reload_pistol", "pistol reload")


## D-111: a crew member placing / fixing a drill plays drill_place; a downed body that moves plays downed_crawl.
func test_drill_place_and_downed_crawl() -> void:
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	crew.setup(0, {"peer_id": 0, "is_ai": true, "display_name": "Bot"}, null)
	var visual: Node3D = crew.get_node(^"Visual") as Node3D
	for c: Node in visual.get_children():
		c.free()
	visual.add_child(_test_rig())
	add_child(crew)
	_nodes.append(crew)
	await wait_frames(2)
	var d: AnimDriver = _drv(crew)
	EventBus.interaction_started.emit(0, crew.slot, &"place_drill")
	d.tick(0.016)
	assert_eq(d.clip, &"drill_place", "placing a drill")
	EventBus.interaction_cancelled.emit(0, crew.slot)
	crew.crew_state = Enums.CrewState.DOWNED
	d.tick(0.016)
	assert_eq(d.clip, &"downed", "downed and still")
	crew.velocity = Vector3(0.3, 0, 0)
	d.tick(0.016)
	assert_eq(d.clip, &"downed_crawl", "downed and moved: crawl")


## D-111 ambient loops: bartender / bouncer / teller activities and `dance` (a / b / c, stable per NPC name).
func test_bar_club_bank_ambient_clips() -> void:
	var cases: Array = [[&"bartender", &"bartender_wipe"], [&"bartender_pour", &"bartender_pour"],
		[&"bouncer", &"bouncer_idle"], [&"teller", &"teller_count"]]
	for c: Array in cases:
		var npc: NpcBase = _npc(&"civilian")
		npc.get_node("Brain").set(&"anim_hint", c[0])
		_drv(npc).tick(0.016)
		assert_eq(_drv(npc).clip, c[1], "%s -> %s" % [c[0], c[1]])
	var dances: Dictionary = {}
	for i: int in range(9):
		var n: NpcBase = _npc(&"civilian")
		n.name = "Dancer_%d" % i
		n.get_node("Brain").set(&"anim_hint", &"dance")
		_drv(n).tick(0.016)
		dances[_drv(n).clip] = true
	assert_true(dances.size() >= 2, "dancers vary (%s)" % [dances.keys()])
	for k: Variant in dances:
		assert_true(k in [&"dance_a", &"dance_b", &"dance_c"], "a dance loop: %s" % k)
	assert_true(CivilianBrain.KNOWN_ACTIVITIES.has(&"dance") and CivilianBrain.KNOWN_ACTIVITIES.has(&"bartender"),
		"civilian activities")


func test_noop_on_capsule_visual() -> void:
	var npc: NpcBase = _npc(&"special", false)  # no EnemyDef / role character (NpcVisuals): the capsule stays
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
	d.tick(1.0)  # past walk_start (v1.10)
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


## characters.md: the shield grip is HandL/Socket (socket -Z = shield face). Only the shield's Visual follows
## it (in a holding pose); the body (collision) stays at the carry offset; with no skeleton nothing moves.
func test_bulwark_shield_follows_handl_socket() -> void:
	var tw: HeavySpecialTweak = HeavySpecialTweak.data()
	var bw: NpcBase = _special("shield_walk")
	var shield: BulwarkShield = tw.bulwark_shield_scene.instantiate() as BulwarkShield
	shield.attach_to(bw, tw.bulwark_shield_offset)
	var vis: Node3D = shield.get_node(^"Visual") as Node3D
	var socket: Node3D = AnimDriver.socket_of(bw, "HandL")
	assert_true(socket != null and shield.grip_socket == socket, "grip socket found on the visual")
	assert_true(vis.global_transform.is_equal_approx(socket.global_transform), "Visual aligned to HandL/Socket")
	assert_true(shield.position.is_equal_approx(tw.bulwark_shield_offset), "the body stays at the carry offset")
	assert_true(shield.get_parent() == bw and shield.get_node_or_null("Collision") != null, "still a carried body")
	bw.global_position = Vector3(3, 0, 1)
	shield.follow_grip(0.016)
	assert_true(vis.global_transform.origin.is_equal_approx(socket.global_transform.origin), "follows the carrier")
	# A socket pose that is not a shield hold (hand at the side, face sideways): the Visual rests on the body.
	socket.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-0.6, 1.0, 0.0))
	assert_false(shield.follow_grip(0.016), "no holding pose: no grip")
	assert_true(vis.transform.is_equal_approx(Transform3D.IDENTITY), "Visual back on the body")
	socket.transform = HANDL_SOCKET
	assert_true(shield.follow_grip(0.016), "holding pose again")
	shield.set_guard(false, tw.bulwark_stagger_shield_offset)
	assert_false(shield.follow_grip(0.016), "lowered guard keeps the stagger offset")
	assert_true(vis.transform.is_equal_approx(Transform3D.IDENTITY), "lowered: Visual on the body")
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


## Lead fix: the first clip a driver plays snaps in (no 0.2 s crossfade from the bind / A-pose at spawn).
func test_first_clip_has_no_fade_in() -> void:
	var npc: NpcBase = _npc()
	var d: AnimDriver = _drv(npc)
	assert_eq(d.clip, &"", "nothing played before the first tick")
	npc.velocity = Vector3.ZERO
	d.tick(0.016)
	assert_eq(d.clip, &"idle")
	assert_near(d.last_blend_s, 0.0, 0.0001, "first clip plays with no fade in")
	npc.velocity = Vector3(0, 0, -1.6)
	d.tick(0.016)
	assert_eq(d.clip, &"walk")
	assert_near(d.last_blend_s, AnimTweak.data().blend_s, 0.0001, "later changes still crossfade")


## Lead fix: above strafe_max_mps (2.2) sideways / backward motion plays run_l / run_r / run_b, not the
## forward run (crew at 3.5 m/s moonwalked); falls back to run when the library lacks the 8-way clips.
func test_directional_run_above_strafe_speed() -> void:
	var npc: NpcBase = _npc()
	var d: AnimDriver = _drv(npc)
	var lib: AnimationLibrary = d.player.get_animation_library(AnimDriver.LIBRARY)
	for c: StringName in [&"run_l", &"run_r", &"run_b"]:
		var a: Animation = Animation.new()
		a.length = 1.0
		a.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(c, a)
	var cases: Array = [
		[Vector3(3.5, 0, 0), &"run_r"], [Vector3(-3.5, 0, 0), &"run_l"], [Vector3(0, 0, 3.5), &"run_b"],
		[Vector3(0, 0, -3.5), &"run"], [Vector3(0, 0, 2.4), &"run_b"], [Vector3(1.2, 0, 0), &"strafe_r"],
		[Vector3(0, 0, 1.3), &"walk_back"],
	]
	for c: Array in cases:
		npc.velocity = c[0]
		for _i: int in 3:
			d.tick(0.016)
		assert_eq(d.clip, c[1], "clip for v=%s" % c[0])
		assert_eq(String(d.player.current_animation), "humanoid/%s" % c[1], "played for v=%s" % c[0])
	npc.velocity = Vector3(3.5, 0, 0)
	d.tick(0.016)
	assert_near(d.player.speed_scale, 1.0, 0.001, "run_r scaled by its 3.5 m/s clip speed")
	var plain: NpcBase = _npc()
	var d2: AnimDriver = _drv(plain)
	plain.velocity = Vector3(0, 0, 3.5)
	for _i: int in 3:
		d2.tick(0.016)
	assert_eq(String(d2.player.current_animation), "humanoid/run", "run_b falls back to run")
