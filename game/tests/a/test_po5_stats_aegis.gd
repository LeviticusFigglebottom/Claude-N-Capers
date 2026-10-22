## D-154 close (B / LEAD): the PO-5 STATS keep Brandt's Aegis shields (META_AEGIS) on their own line, out of police /
## specials / composition, so the Bulwark share measures the director's funnel only.
extends TestCase

const AEGIS_DEF: EnemyDef = preload("res://systems/ai/data/enemies/aegis.tres")

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_aegis_counted_apart() -> void:
	var tw: DirectorTweak = (load("res://systems/director/director_tweak.tres") as DirectorTweak).duplicate() \
		as DirectorTweak
	tw.first_control_s = 100.0
	tw.first_responder_groups = 0
	_rt = await HeistLauncher.launch(&"dev_sandbox", 1411, Enums.Difficulty.BRUTAL, self,
		{"ai_teammates": 0, "captain": false, "director_tweak": tw})
	var d: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_true(d != null, "the director")
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	var pts: Array[Node3D] = d.valid_spawn_points()
	var shield: NpcBase = d.spawn_enemy(AEGIS_DEF, pts[0].global_transform, pts[0])
	shield.set_meta(AegisCaptain.META_AEGIS, true)
	var normal: NpcBase = d.spawn_enemy(AEGIS_DEF, pts[0].global_transform, pts[0])
	var stats: Po5Stats = Po5Stats.new()
	stats._rt = _rt
	stats._sample()
	assert_eq(stats.aegis, 1, "the flagged shield on the Aegis line")
	assert_eq(int(stats.enemies.get(AEGIS_DEF.id, 0)), 1, "only the unflagged one in the composition")
	assert_true(normal != null and stats.summary().contains("STATS aegis=1"), "its own STATS line")
