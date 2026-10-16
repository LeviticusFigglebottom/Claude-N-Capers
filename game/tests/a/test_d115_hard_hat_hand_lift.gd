## D-115 (ENV D civilian clip audit R1): on a hard-hat rig (dock_worker) the hands-on-head clips lift the hands
## over the hat shell (HardHatHandLift, AnimTweak.hard_hat_*); the beanie (dock_packer) gets no lift; outside the
## lift clips the influence blends back to 0.
extends TestCase

const HINT_SCRIPT: String = "extends Node\nvar anim_hint: StringName = &\"idle\"\n"

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


func _npc(char_id: String) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = &"civilian"
	npc.visual_scene = load(NpcVisuals.scene_path(char_id)) as PackedScene
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


## How far the right hand sits along the head's up axis, in the final (modified) pose: modifier results are only
## readable in skeleton_updated.
func _hand_y(d: AnimDriver) -> float:
	var sk: Skeleton3D = d.rig.get_node("Skeleton3D") as Skeleton3D
	var out: Array[float] = [NAN]
	var grab: Callable = func() -> void:
		var head: Transform3D = sk.get_bone_global_pose(sk.find_bone("head"))
		var hand: Vector3 = sk.get_bone_global_pose(sk.find_bone("hand.R")).origin
		out[0] = (hand - head.origin).dot(head.basis.y.normalized())
	sk.skeleton_updated.connect(grab)
	await wait_frames(3)
	sk.skeleton_updated.disconnect(grab)
	return out[0]


func test_d115_hard_hat_lifts_hands_on_head() -> void:
	var w: NpcBase = _npc("dock_worker")
	var p: NpcBase = _npc("dock_packer")
	await wait_frames(2)
	var dw: AnimDriver = AnimDriver.of(w)
	var dp: AnimDriver = AnimDriver.of(p)
	assert_true(dw != null and dw.hat_lift != null, "dock_worker (hard hat): lift modifier")
	assert_true(dp != null and dp.hat_lift == null, "dock_packer (beanie): none")
	var tw: AnimTweak = AnimTweak.data()
	var lifted: Array[StringName] = []
	for hint: StringName in [&"surrender", &"cower", &"hands_up"]:
		w.get_node("Brain").set(&"anim_hint", hint)
		await wait_seconds(2.5)  # the driver runs on its own (_process): clip, blend, pose
		assert_true(tw.hard_hat_lift_clips.has(dw.clip), "%s: a lift clip plays (%s)" % [hint, dw.clip])
		assert_near(dw.hat_lift.influence, 1.0, 0.001, "%s: lift blended in" % hint)
		# Same frozen pose, lift on vs off.
		dw.player.pause()
		dw.set_process(false)
		var on_y: float = await _hand_y(dw)
		var applied: float = dw.hat_lift.applied[1]
		dw.hat_lift.influence = 0.0
		var off_y: float = await _hand_y(dw)
		print("[D115 hat] %s applied %.3f, hand along head-up on %.3f off %.3f" % [hint, applied, on_y, off_y])
		if applied > 0.0:
			assert_true(on_y - off_y > tw.hard_hat_hand_lift_m * 0.5, "%s: hand lifted (%.3f m)" % [hint, on_y - off_y])
			lifted.append(hint)
		else:
			assert_true(absf(on_y - off_y) < 0.002, "%s: hand off the head: untouched" % hint)
		dw.hat_lift.influence = 1.0
		dw.set_process(true)
		dw.player.play()
	assert_true(lifted.has(&"surrender") or lifted.has(&"cower"), "a hands-on-head clip lifts (%s)" % [lifted])
	w.get_node("Brain").set(&"anim_hint", &"idle")
	await wait_seconds(1.0)
	assert_near(dw.hat_lift.influence, 0.0, 0.001, "idle: lift blended out")
	assert_false(dw.hat_lift.active, "inactive outside the lift clips")
