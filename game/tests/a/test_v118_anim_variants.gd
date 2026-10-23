## characters.md v1.18 (D-116 follow-up, ENV D bf16b2c1): pose variants (hands_up / surrender / surrender_idle /
## kneel_cuffed, one index per NPC = hash(net_id) % 3), the surrender* -> surrender_idle* hold, hit-zone flinches
## (hit_head / hit_chest / hit_shoulder_* / hit_leg_*, hit_react* fallback), posed deaths and the hard-hat lift on
## the variants. Runs on a real cast rig (dock_worker: hard hat); a sub-case whose clip the rig lacks is skipped
## with a print.
extends TestCase

const HINT_SCRIPT: String = "extends Node\nvar anim_hint: StringName = &\"idle\"\n"
const CHAR_ID: String = "dock_worker"

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


func _npc(net_id: int, role: StringName = &"civilian") -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = role
	npc.net_id = net_id
	npc.visual_scene = load(NpcVisuals.scene_path(CHAR_ID)) as PackedScene
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
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
	return npc


## A net id whose variant index (hash(net_id) % 3) is `index`.
static func _id_for(index: int, start: int = 91000) -> int:
	var n: int = start
	while absi(hash(n)) % 3 != index:
		n += 1
	return n


func _has(d: AnimDriver, c: StringName) -> bool:
	return d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, c])


func _missing(d: AnimDriver, clips: Array[StringName], what: String) -> bool:
	for c: StringName in clips:
		if not _has(d, c):
			print("[v118] skip %s: the rig has no %s (ENV D assets not checked out)" % [what, c])
			return true
	return false


func _playing(d: AnimDriver) -> String:
	return String(d.player.current_animation) if d.player.is_playing() else "<stopped>"


func test_variant_pick_is_stable_and_spreads() -> void:
	var npc: NpcBase = _npc(_id_for(0))
	await wait_frames(1)
	var d: AnimDriver = AnimDriver.of(npc)
	assert_true(d != null and d.player != null, "real rig animated")
	var seen: Dictionary = {}
	for n: int in range(5000, 5030):
		npc.net_id = n
		var i: int = d.variant_index()
		assert_eq(d.variant_index(), i, "net id %d: the same index on every call" % n)
		assert_eq(i, absi(hash(n)) % 3, "net id %d: index = hash(net_id) %% 3 (every peer computes the same)" % n)
		seen[i] = true
	assert_eq(seen.size(), 3, "30 net ids spread over all three variants")
	for idx: int in 3:
		npc.net_id = _id_for(idx)
		for group: StringName in AnimDriver.VARIANT_GROUPS:
			var want: StringName = (AnimDriver.VARIANT_GROUPS[group] as Array)[idx]
			if not _has(d, want):
				print("[v118] skip pick %s: no %s" % [group, want])
				continue
			assert_eq(d.pose_variant(group), want, "index %d: %s -> %s (same index in every group)" % [idx, group, want])
	assert_eq(d.pose_variant(&"cower_stand"), &"cower_stand", "not a variant group: unchanged")


func test_surrender_b_holds_surrender_idle_b() -> void:
	var npc: NpcBase = _npc(_id_for(1))
	await wait_frames(1)
	var d: AnimDriver = AnimDriver.of(npc)
	if _missing(d, [&"surrender_b", &"surrender_idle_b"], "surrender_b hold"):
		return
	npc.get_node("Brain").set(&"anim_hint", &"surrender")
	await wait_frames(2)
	assert_eq(d.clip, &"surrender_b", "index 1 surrenders with surrender_b")
	assert_eq(_playing(d), "humanoid/surrender_b", "player agrees")
	await wait_seconds(2.4)  # surrender_b is 1.8 s
	print("[v118] surrendered: driver %s player %s blend %.2f" % [d.clip, _playing(d), d.last_blend_s])
	assert_eq(d.clip, &"surrender_idle_b", "after surrender_b: its own loop surrender_idle_b")
	assert_eq(_playing(d), "humanoid/surrender_idle_b", "player and driver agree")
	assert_true(d.player.speed_scale > 0.0, "the loop plays (not the frozen fallback)")
	assert_eq(d.last_blend_s, 0.0, "chained on the shared frame, no crossfade")
	await wait_seconds(1.0)
	assert_eq(_playing(d), "humanoid/surrender_idle_b", "still looping 1 s later")


func test_variant_loops_start_at_an_offset() -> void:
	var npc: NpcBase = _npc(_id_for(2))
	await wait_frames(1)
	var d: AnimDriver = AnimDriver.of(npc)
	if _missing(d, [&"hands_up_c"], "loop offset"):
		return
	npc.get_node("Brain").set(&"anim_hint", &"hands_up")
	await wait_frames(2)
	assert_eq(d.clip, &"hands_up_c", "index 2 raises hands with hands_up_c")
	assert_true(d._loop_offsets.has(&"hands_up"), "an offset was drawn for the hands_up group")
	var frac: float = d._loop_offsets[&"hands_up"]
	assert_true(frac >= 0.0 and frac < 1.0, "offset fraction in [0, 1) (%.3f)" % frac)


func test_hit_zones_pick_their_clip() -> void:
	var npc: NpcBase = _npc(_id_for(0, 92000), &"guard")
	await wait_frames(1)
	var d: AnimDriver = AnimDriver.of(npc)
	var head: float = 1.65
	var cases: Array = [
		[Enums.HitZone.HEAD, Vector3(0, head, 0), &"hit_head"],
		[Enums.HitZone.BODY, Vector3(0, 1.2, 0), &"hit_chest"],
		[Enums.HitZone.LIMB, Vector3(-0.25, 1.4, 0), &"hit_shoulder_l"],
		[Enums.HitZone.LIMB, Vector3(0.25, 1.4, 0), &"hit_shoulder_r"],
		[Enums.HitZone.LIMB, Vector3(-0.12, 0.45, 0), &"hit_leg_l"],
		[Enums.HitZone.LIMB, Vector3(0.12, 0.45, 0), &"hit_leg_r"],
	]
	for c: Array in cases:
		if _missing(d, [c[2]], "zone %s" % c[2]):
			continue
		d._last_hit_react_t = -100.0
		EventBus.damage_applied.emit(npc.net_id, 0, Damage.info(12.0, Enums.DamageType.BULLET, int(c[0]), &"",
			c[1], Vector3(0, 0, 1)))
		d.tick(0.016)
		assert_eq(d.clip, c[2], "zone %d at %s -> %s" % [c[0], c[1], c[2]])
		assert_eq(_playing(d), "humanoid/%s" % c[2], "player agrees (%s)" % c[2])
	# Root space, not world: turned 180 deg, a world +X limb hit is on the body's left.
	if not _missing(d, [&"hit_shoulder_l"], "rotated zone"):
		npc.rotation.y = PI
		d._visual_yaw = npc.global_rotation.y  # already facing there (no turn-in-place one-shot)
		d._prev_body_yaw = d._visual_yaw
		d._last_hit_react_t = -100.0
		EventBus.damage_applied.emit(npc.net_id, 0, Damage.info(12.0, Enums.DamageType.BULLET, Enums.HitZone.LIMB, &"",
			Vector3(0.25, 1.4, 0), Vector3(0, 0, -1)))
		d.tick(0.016)
		assert_eq(d.clip, &"hit_shoulder_l", "turned body: world +X is its left shoulder")


func test_unknown_zone_falls_back_to_hit_react() -> void:
	var npc: NpcBase = _npc(_id_for(1, 93000), &"guard")
	await wait_frames(1)
	var d: AnimDriver = AnimDriver.of(npc)
	if _missing(d, [&"hit_react"], "fallback"):
		return
	var infos: Array[Dictionary] = [
		{"direction": Vector3(0, 0, 1), "amount": 12.0, "killed": false},
		Damage.info(12.0, Enums.DamageType.BULLET, Enums.HitZone.WEAKPOINT, &"", Vector3(0, 1, 0), Vector3(0, 0, 1)),
		Damage.info(12.0, Enums.DamageType.EXPLOSION, Enums.HitZone.BODY, &"", Vector3(0, 1, 0), Vector3(0, 0, 1)),
		Damage.info(12.0, Enums.DamageType.BULLET, 99, &"", Vector3(0, 1, 0), Vector3(0, 0, 1)),
	]
	for info: Dictionary in infos:
		d._last_hit_react_t = -100.0
		EventBus.damage_applied.emit(npc.net_id, 0, info)
		d.tick(0.016)
		var want: StringName = &"hit_react"
		if int(info.get("type", -1)) == Enums.DamageType.EXPLOSION and d.combat.stagger_clip() != &"":
			want = d.combat.stagger_clip()  # D-116: an explosion staggers a non-shield NPC (stagger_<fam>)
		d._oneshot_left = 0.0
		assert_eq(d.clip, want, "no usable zone (%s, type %s) -> directional hit_react" % [
			info.get("zone", "none"), info.get("type", "none")])


func test_death_from_variant_pose_is_posed() -> void:
	var tw: AnimTweak = AnimTweak.data()
	for pose: StringName in [&"kneel_cuffed", &"surrender"]:
		var npc: NpcBase = _npc(_id_for(1, 94000 + (0 if pose == &"kneel_cuffed" else 500)))
		await wait_frames(1)
		var d: AnimDriver = AnimDriver.of(npc)
		var v: StringName = d.pose_variant(pose)
		if v == pose:
			print("[v118] skip posed death %s: no variant on the rig" % pose)
			continue
		npc.get_node("Brain").set(&"anim_hint", pose)
		await wait_frames(2)
		assert_eq(d.clip, v, "%s plays its variant %s" % [pose, v])
		assert_true(tw.death_by_pose.has(v), "%s has a posed death" % v)
		var posed: StringName = tw.death_by_pose[v]
		if _missing(d, [posed], "posed death %s" % posed):
			continue
		npc.last_damage = {"direction": Vector3(0, 0, 1), "type": Enums.DamageType.BULLET}
		npc.die({"direction": Vector3(0, 0, 1)})
		assert_eq(d.choose_clip(), posed, "dies from %s with %s (never a standing death)" % [v, posed])
	for held: StringName in [&"surrender_idle", &"surrender_idle_b", &"surrender_idle_c"]:
		assert_eq(tw.death_by_pose.get(held, &""), &"death_kneel", "%s kneels: death_kneel" % held)


func test_hard_hat_lift_on_the_variants() -> void:
	var tw: AnimTweak = AnimTweak.data()
	for group: StringName in AnimDriver.VARIANT_GROUPS:
		if group in [&"flee", &"cower", &"queue_idle", &"idle", &"idle_alert"]:
			continue  # D-116 civ panic: flee* runs; cower_c holds the hands by the face (cower / cower_b below);
			# OF-A6 queue_idle* is an ambient idle (hands at the waist / phone / arms crossed), not a hands-up pose;
			# D 7d86014f idle* / idle_alert* likewise (a watch check, a stretch, a hand on the shoulder radio)
		for v: Variant in AnimDriver.VARIANT_GROUPS[group]:
			assert_true(tw.hard_hat_lift_clips.has(v), "%s is a hard-hat lift clip" % v)
	assert_true(tw.hard_hat_lift_clips.has(&"cower") and tw.hard_hat_lift_clips.has(&"cower_b"),
		"cower / cower_b (forearms over the head) lift")
	for pair: Array in [[&"hands_up", 1], [&"kneel_cuffed", 2]]:
		var npc: NpcBase = _npc(_id_for(int(pair[1]), 95000 + int(pair[1]) * 100))
		await wait_frames(1)
		var d: AnimDriver = AnimDriver.of(npc)
		var v: StringName = d.pose_variant(pair[0])
		if v == pair[0]:
			print("[v118] skip hat lift %s: no variant on the rig" % pair[0])
			continue
		assert_true(d.hat_lift != null, "dock_worker wears a hard hat: lift modifier")
		npc.get_node("Brain").set(&"anim_hint", pair[0])
		await wait_seconds(0.6)
		assert_eq(d.clip, v, "%s variant %s plays" % [pair[0], v])
		assert_near(d.hat_lift.influence, 1.0, 0.001, "%s: the lift is blended in" % v)
		assert_true(d.hat_lift.active, "%s: the lift is active" % v)


## D 7d86014f (idle_variants / idle_alert_variants): a calm body's idle and an alerted one's idle_alert play its
## variant (same index as every group); a rig without the variants keeps the base clip (until D's round lands).
func test_idle_and_idle_alert_follow_the_body_index() -> void:
	for idx: int in 3:
		var npc: NpcBase = _npc(_id_for(idx, 93000 + idx * 50), &"guard")
		await wait_frames(1)
		var d: AnimDriver = AnimDriver.of(npc)
		var want: StringName = (AnimDriver.VARIANT_GROUPS[&"idle"] as Array)[idx]
		var got: StringName = d.choose_clip()
		assert_eq(got, want if _has(d, want) else &"idle", "index %d calm: %s" % [idx, got])
		npc.alert_state = Enums.AlertState.ALARMED
		var want_a: StringName = (AnimDriver.VARIANT_GROUPS[&"idle_alert"] as Array)[idx]
		var got_a: StringName = d.choose_clip()
		if String(got_a).begins_with("idle_alert_") and not (AnimDriver.VARIANT_GROUPS[&"idle_alert"] as Array).has(got_a):
			continue  # an armed hold (idle_alert_<kind>) is never varied
		assert_eq(got_a, want_a if _has(d, want_a) else &"idle_alert", "index %d alerted: %s" % [idx, got_a])
