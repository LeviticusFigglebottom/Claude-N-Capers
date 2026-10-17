## D-116 npc_oneshot (net.md): the host's NPC presentation one-shots (door breach door_kick_<fam> / shield_bang,
## civilian panic_start) go to the clients through HeistNetSync._rpc_npc_oneshot [net_id, clip, start_s, speed], and
## the held cuff hint through the NPC entity state key "ah". This file covers each side in process (NetOneshot.play /
## relay on the host, NetOneshot.apply / CivPanic.start_net / the "ah" key); test_d116_npc_oneshot_loopback.gd runs
## the real host -> client path.
extends TestCase

const ANIM_TEST: GDScript = preload("res://tests/a/test_anim_driver.gd")
const HINT_SCRIPT: String = "extends Node\nvar anim_hint: StringName = &\"\"\n"
const DT: float = 1.0 / 60.0
const KICK: StringName = &"door_kick_rifle"
const KICK_LEN: float = 2.8
const PANIC_LEN: float = 0.8

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


## An NPC (`role`) on the code-built test rig plus door_kick_rifle (2.8 s) and panic_start (0.8 s).
func _npc(role: StringName) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = role
	npc.net_id = 81234
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	var rig: Node3D = ANIM_TEST._test_rig()
	var lib: AnimationLibrary = (rig.get_node(^"AnimationPlayer") as AnimationPlayer).get_animation_library(
		AnimDriver.LIBRARY)
	for c: Array in [[KICK, KICK_LEN], [&"panic_start", PANIC_LEN]]:
		var a: Animation = Animation.new()
		a.length = float(c[1])
		lib.add_animation(c[0], a)
	visual.add_child(rig)
	npc.add_child(visual)
	var gs: GDScript = GDScript.new()
	gs.source_code = HINT_SCRIPT
	gs.reload()
	var brain: Node = Node.new()
	brain.name = "Brain"
	brain.set_script(gs)
	npc.add_child(brain)
	add_child(npc)
	_nodes.append(npc)
	var d: AnimDriver = AnimDriver.of(npc)
	d.set_process(false)
	d.tick(DT)
	return npc


## Host: NetOneshot.play starts the clip and records what it sent (no session here: nothing goes on the wire).
func test_host_play_records_the_cue() -> void:
	var npc: NpcBase = _npc(&"police")
	var d: AnimDriver = AnimDriver.of(npc)
	NetOneshot.play(d, KICK, (KICK_LEN - 0.4) / 1.25, 1.25, 0.4)
	d.tick(DT)
	assert_eq(d.clip, KICK, "the host plays it")
	assert_eq(d.last_net_oneshot, [KICK, 0.4, 1.25], "and sends [clip, start_s, speed]")
	assert_near(d.net_oneshot_left, 0.0, 0.0001, "the host's own one-shot is not a received one")


## Client: the cue plays the clip from start_s at speed for the rest of the clip; no turn clip cuts it.
func test_client_apply_plays_with_the_hosts_timing() -> void:
	var npc: NpcBase = _npc(&"police")
	var d: AnimDriver = AnimDriver.of(npc)
	NetOneshot.apply(d, KICK, 0.5, 1.2)
	var want_left: float = (KICK_LEN - 0.5) / 1.2
	assert_near(d.net_oneshot_left, want_left, 0.0001, "held for the rest of the clip")
	d.tick(DT)
	assert_eq(d.clip, KICK, "plays the host's clip")
	assert_near(d.player.speed_scale, 1.2, 0.0001, "at the host's speed")
	assert_near(d.player.current_animation_position, 0.5, 1.2 * DT + 0.001, "from the host's start offset")
	npc.rotation.y += deg_to_rad(60.0)  # the body turns while it kicks: no turn clip replaces the kick
	var t: float = DT
	while d.net_oneshot_left > 0.0 and t < 4.0:
		d.tick(DT)
		t += DT
		if d.net_oneshot_left > DT:
			assert_eq(d.clip, KICK, "not cut by a turn (t %.2f)" % t)
	assert_near(t, want_left, 2.0 * DT, "lasted the rest of the clip")
	d.tick(DT)
	assert_true(String(d.clip).begins_with("turn_"), "then the turn plays (%s)" % d.clip)


func test_client_apply_ignores_a_missing_clip() -> void:
	var npc: NpcBase = _npc(&"police")
	var d: AnimDriver = AnimDriver.of(npc)
	var before: StringName = d.clip
	NetOneshot.apply(d, &"door_kick_nope", 0.0, 1.0)
	d.tick(DT)
	assert_eq(d.clip, before, "a clip the rig lacks plays nothing")
	assert_near(d.net_oneshot_left, 0.0, 0.0001)


## Client: panic_start through CivPanic (start offset taken off its length), then the chosen cower.
func test_client_panic_start_from_the_cue() -> void:
	var npc: NpcBase = _npc(&"civilian")
	var d: AnimDriver = AnimDriver.of(npc)
	npc.get_node("Brain").set(&"anim_hint", &"cower")
	d.civ_panic.done = true  # as on a client that already saw the cower without starting panic_start
	d.tick(DT)
	assert_eq(d.clip, &"cower", "cowering")
	NetOneshot.apply(d, &"panic_start", 0.3, 1.0)
	d.tick(DT)
	assert_eq(d.clip, &"panic_start", "the host's panic_start plays")
	var t: float = DT
	while d.clip == &"panic_start" and t < 2.0:
		d.tick(DT)
		t += DT
	assert_near(t, PANIC_LEN - 0.3, 2.0 * DT, "for the rest of the clip")
	assert_eq(d.clip, &"cower", "then cower")


## The held cuff hint rides the NPC entity state ("ah"): set while the brain cuffs, "" for any other hint. Applying it
## is a client-only step (the host keeps its brain's hint).
func test_cuff_hint_in_the_entity_state() -> void:
	var npc: NpcBase = _npc(&"police")
	var brain: Node = npc.get_node("Brain")
	brain.set(&"anim_hint", &"cuff")
	var st: Dictionary = NetEntityCodec.state_of(npc)
	assert_eq(st.get("ah", null), &"cuff", "the cuff hint replicates")
	brain.set(&"anim_hint", &"aim")
	assert_eq(NetEntityCodec.state_of(npc).get("ah", null), &"", "other hints do not")
	NetEntityCodec.apply_state(npc, {"ah": &"cuff"})
	assert_false(npc.has_meta(AnimDriver.META_NET_HINT), "the host ignores it")
	assert_eq(AnimDriver.HINT_CLIPS.get(&"cuff"), &"interact_low", "cuff = interact_low")
