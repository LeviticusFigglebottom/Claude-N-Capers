## X-5 (heist_completion.md): Gallery Night staff with a `desk_work` activity and no seat under them played the
## seated desk_work clip standing / floating. The PO6-06 rule (CivilianBrain.seated_or_standing) swaps a seated
## activity with no seat for its standing counterpart (StealthTweak.civilian_unseated_activity: desk_work -> teller,
## the teller_count clip, standing hands-on-counter; desk_type is a seated rig clip, not a standing one). GN map data
## (env/c-worlds): the desk_work spawns are the Curator (curator_office, CuratorChair), the AdminPA (admin_pa,
## AdminPAChair) and the camera operator (CameraStation Seat); the StaffCO / CS / AO patrol points have no seat
## (test_x5_gn_staff_unseated_pause). Over seeds that resolve the curator office and the staffed security room, no
## GN NPC plays a seated clip without a seat, and a desk_work clerk spawned off the chair stands.
extends TestCase

## AnimDriver clips that put the root under a seat centre (anim_humanoid.py seated set).
const SEATED_CLIPS: Array[StringName] = [&"desk_work", &"desk_type", &"phone_seated", &"sit_chair", &"sit_chair_watch",
	&"cower_seated"]
## Seeds whose variants spawn the GN desk_work staff (curator_office: 5, 6; sec_staffed: 1, 6).
const SEEDS: Array[int] = [5, 6, 1]

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _clip(npc: NpcBase) -> StringName:
	var ad: AnimDriver = AnimDriver.of(npc)
	return ad.choose_clip() if ad != null else &""


func test_x5_gn_no_seated_clip_without_a_seat() -> void:
	var desk_staff: int = 0
	var seated_ok: int = 0
	for s: int in SEEDS:
		_rt = await HeistLauncher.launch(&"gallery_night", s, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
		assert_true(_rt != null, "GN seed %d launched" % s)
		await wait_seconds(1.0)
		for role: StringName in [&"civilian", &"guard"]:
			for n: Node in _rt.npcs(role):
				var npc: NpcBase = n as NpcBase
				var act: StringName = StringName(npc.spawn_info.get("idle_activity", &""))
				var clip: StringName = _clip(npc)
				var seat: bool = CivilianBrain.has_seat_under(npc)
				if act == &"desk_work" or act == &"teller":
					desk_staff += 1
					print("X-5 GN seed %d %s %s tags %s act %s seat %s clip %s at %s" % [s, role, npc.name,
						npc.spawn_info.get("tags"), act, seat, clip, npc.global_position])
				if SEATED_CLIPS.has(clip):
					assert_true(seat, "seed %d %s %s plays seated %s only on a seat (at %s)" % [s, role, npc.name, clip,
						npc.global_position])
					seated_ok += 1
		_rt.teardown()
		_rt = null
		await wait_frames(3)
	assert_true(desk_staff >= 4, "GN desk staff seen over the seeds (%d)" % desk_staff)
	assert_true(seated_ok >= 2, "the curator and the camera operator sit on their real seats (%d)" % seated_ok)


func test_x5_gn_desk_work_off_the_chair_stands() -> void:
	_rt = await HeistLauncher.launch(&"gallery_night", 5, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	await wait_seconds(0.5)
	var chair: Node3D = _rt.map.get_node_or_null(^"Variants/Group_curator_route/Slot_curator_office/CuratorChair") as Node3D
	assert_true(chair != null, "GN CuratorChair (curator_office)")
	if chair == null:
		return
	# 1.2 m beside the curator's chair, on the same floor: no seat there.
	var xf: Transform3D = Transform3D(chair.global_transform.basis, chair.global_position + Vector3(1.2, 0.05, 0.0))
	var civ: NpcBase = _rt.spawn_npc(&"civilian", xf, {"idle_activity": &"desk_work", "tags": [&"civ_curator"]})
	await wait_physics_frames(5)
	var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	assert_false(CivilianBrain.has_seat_under(civ), "no seat 1.2 m off the chair")
	assert_eq(b.anim_hint, &"teller", "desk_work with no seat -> the standing desk activity")
	var clip: StringName = _clip(civ)
	if clip != &"":
		assert_eq(clip, &"teller_count", "plays the standing desk clip (teller_count)")
		assert_false(SEATED_CLIPS.has(clip), "not a seated clip on thin air")


## The seated aliases follow the same rule (`desk` plays desk_work; desk_type / sit_chair / sit_chair_watch are seated).
func test_x5_seated_aliases_stand_without_a_seat() -> void:
	_rt = await HeistLauncher.launch(&"unit_x5_alias", 3, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true})
	var g: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(4, 0.05, 4)), {"no_patrol": true})
	await wait_physics_frames(3)
	for a: StringName in [&"desk", &"desk_type", &"sit_chair", &"sit_chair_watch"]:
		var st: StringName = CivilianBrain.seated_or_standing(g, a)
		assert_ne(st, a, "%s on thin air swaps" % a)
		assert_false(SEATED_CLIPS.has(StringName(AnimDriver.HINT_CLIPS.get(st, st))), "%s -> %s is a standing clip" % [a, st])
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(-4, 0.05, 4)), {"idle_activity": &"desk"})
	await wait_physics_frames(5)
	assert_eq((civ.get_node(^"Brain") as CivilianBrain).anim_hint, &"teller", "a `desk` civilian with no seat stands")
