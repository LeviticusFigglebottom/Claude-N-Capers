## PO6-06 (D-114, S7.5): civilians spawn standing / working, never in a hostage or downed pose. On every heist,
## one second after the real map loads (casing start, several variant seeds) every civilian is CALM, in an idle
## or wander mode, not in G.HOSTAGE, and its AnimDriver plays a standing or seated-working clip (no tied /
## kneel_cuffed / lie_down / cower / hands_up / surrender / downed) with the head above a crouch. The only
## exception is a pose a map entry explicitly asks for: `sit_bed_read` (Kessler, D-069). A loud-only heist
## (Dockside Burn, S11.3) panics its civilians at the start (they flee, then cower: S7.4), which is the
## mission's reason; even there nobody starts down, tied or as a hostage. Root cause of the PO report: desk_work /
## sit civilians with no chair under them (GH jeweler at the workshop bench, admin clerk behind the desk, counter
## associate) played the seated loop on thin air, hips 0.54 m up, which reads as a hostage on the floor; a seated
## loop now needs a seat (CivilianBrain.has_seat_under) or the civilian does the standing activity. Plus: every
## civilian visual x every map idle activity resolves to a standing / seated clip.
extends TestCase

const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"dockside_burn", &"shadow_ledger", &"gallery_night"]
const SEEDS: Array[int] = [1, 3, 7]
## Clips that put a calm civilian on the floor / in a hostage pose (AnimDriver.POSE_CLIPS + downed_crawl).
const BAD_CLIPS: Array[StringName] = [
	&"tied", &"kneel_cuffed", &"lie_down", &"cower", &"hands_up", &"surrender", &"downed", &"tased",
	&"cower_stand", &"cower_seated", &"downed_crawl",
]
## Hostage / surrender poses: never at the start, loud or not.
const HOSTAGE_CLIPS: Array[StringName] = [&"tied", &"kneel_cuffed", &"lie_down", &"hands_up", &"surrender"]
## Seated loops (characters.md npc_seat: the root under the seat centre).
const SEATED_CLIPS: Array[StringName] = [&"desk_work", &"desk_type", &"phone_seated", &"sit_chair", &"sit_chair_watch"]
## Explicitly authored low poses (D-069: Kessler reads in bed).
const AUTHORED_LOW: Array[StringName] = [&"sit_bed_read"]
## Head height (m above the feet) below which a body reads as on the floor (seated at a desk ~1.05,
## standing ~1.55, cower ~0.62).
const MIN_HEAD_M: float = 0.9

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


static func _head_height(npc: NpcBase) -> float:
	var arr: Array[Node] = npc.find_children("*", "Skeleton3D", true, false)
	if arr.is_empty():
		return INF  # capsule placeholder: no pose to check
	var sk: Skeleton3D = arr[0] as Skeleton3D
	var hi: int = sk.find_bone("head")
	if hi < 0:
		hi = sk.find_bone("Head")
	if hi < 0:
		return INF
	return (sk.global_transform * sk.get_bone_global_pose(hi)).origin.y - npc.global_position.y


## Asserts one civilian is up and calm; returns 1 when its pose was checked (animated visual), else 0.
func _check_civilian(npc: NpcBase, where: String, loud_start: bool = false) -> int:
	var tags: Array = npc.spawn_info.get("tags", [])
	var what: String = "%s %s (%s, idle %s)" % [where, npc.name, tags, npc.spawn_info.get("idle_activity", &"")]
	assert_false(npc.is_in_group(G.HOSTAGE), "%s: not a hostage" % what)
	assert_false(npc.alert_state in [Enums.AlertState.INTIMIDATED, Enums.AlertState.TIED, Enums.AlertState.SURRENDERED],
		"%s: not intimidated / tied (alert %s)" % [what, Enums.AlertState.keys()[npc.alert_state]])
	if not loud_start:
		assert_eq(npc.alert_state, Enums.AlertState.CALM, "%s: spawns CALM" % what)
	var b: CivilianBrain = npc.get_node_or_null(^"Brain") as CivilianBrain
	if b != null:
		assert_false(b.is_down() or b.is_tied(), "%s: not down / tied" % what)
		if not loud_start:
			assert_true(b.mode == CivilianBrain.Mode.IDLE or b.mode == CivilianBrain.Mode.WANDER,
				"%s: idle / wandering, not mode %s" % [what, CivilianBrain.Mode.keys()[b.mode]])
	var ad: AnimDriver = npc.get_node_or_null(^"AnimDriver") as AnimDriver
	if ad == null or ad.player == null:
		return 0
	var clip: StringName = ad.choose_clip()
	assert_false(HOSTAGE_CLIPS.has(clip), "%s: plays %s (a hostage pose)" % [what, clip])
	if loud_start:
		return 1
	assert_false(BAD_CLIPS.has(clip), "%s: plays %s (a floor pose)" % [what, clip])
	if not AUTHORED_LOW.has(clip):
		var h: float = _head_height(npc)
		assert_true(h >= MIN_HEAD_M, "%s: head %.2f m above the feet (clip %s): on the floor" % [what, h, clip])
	if SEATED_CLIPS.has(clip):  # a seated loop only on a real seat (never sitting on thin air)
		assert_true(CivilianBrain.has_seat_under(npc), "%s: plays %s with no seat under it" % [what, clip])
	print("PO6-06   %s: clip %s, seat %s" % [what, clip, CivilianBrain.has_seat_under(npc)])
	return 1


func test_po6_06_heist_civilians_spawn_standing() -> void:
	for heist: StringName in HEISTS:
		for sd: int in SEEDS:
			_rt = await HeistLauncher.launch(heist, sd, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
			assert_true(_rt != null, "launched %s" % heist)
			if _rt == null:
				continue
			await wait_seconds(1.0)
			var civs: Array[Node] = _rt.npcs(&"civilian")
			assert_false(civs.is_empty(), "%s seed %d has civilians" % [heist, sd])
			var loud_start: bool = _rt.heist_mode == Enums.HeistMode.LOUD_ONLY
			var animated: int = 0
			for n: Node in civs:
				animated += _check_civilian(n as NpcBase, "%s seed %d" % [heist, sd], loud_start)
			assert_eq(get_tree().get_nodes_in_group(G.HOSTAGE).size(), 0, "%s seed %d: no hostages at start" % [heist, sd])
			print("PO6-06 %s seed %d: %d civilians, %d animated" % [heist, sd, civs.size(), animated])
			_rt.teardown()
			_rt = null
			await wait_frames(2)


func test_po6_06_every_civilian_visual_and_activity_stands() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 1, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	var tags: Array[StringName] = [&"civ_staff_manager", &"civ_customer", &"civ_staff_admin", &"civ_staff_workshop",
		&"civ_cleaner", &"civ_it", &"civ_partner", &"civ_worker"]
	# Every idle_activity a shipped map uses (SpawnPoint.idle_activity), plus none.
	var acts: Array[StringName] = [&"", &"idle", &"phone", &"browse", &"desk_work", &"sit", &"queue", &"smoke",
		&"look", &"curator_inspect", &"walk_text", &"text", &"mug"]
	var made: Array[NpcBase] = []
	var i: int = 0
	for t: StringName in tags:
		for a: StringName in acts:
			var tt: Array[StringName] = [t]
			var pos: Vector3 = Vector3(-40.0 - float(i % 12) * 2.0, 0.05, -40.0 - float(i / 12) * 2.0)
			made.append(_rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, pos), {"idle_activity": a, "tags": tt}))
			i += 1
	await wait_seconds(1.0)
	var animated: int = 0
	for npc: NpcBase in made:
		animated += _check_civilian(npc, "spawned")
	assert_true(animated > 0, "civilian visuals are animated")
