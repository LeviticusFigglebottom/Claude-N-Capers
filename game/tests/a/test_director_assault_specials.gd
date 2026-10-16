## Round-227 P3 red (LEAD): PD2 brings specials mostly WITH the assault. Each BUILD/SUSTAIN pick keeps the plain squad
## and, with DirectorTweak.assault_special_share[stage], adds the specials of a special-carrying group in front of it
## (added, not swapped: the PO6-16 force refill keeps its rate). The between-wave CONTROL roll stays rarer.
extends TestCase

const PICKS: int = 400

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _director() -> AssaultDirector:
	_rt = await HeistLauncher.launch(&"dev_sandbox", 2270, Enums.Difficulty.HAZARDOUS, self, {"captain": false})
	await wait_physics_frames(2)
	var d: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	d.assault_phase = Enums.AssaultPhase.SUSTAIN
	return d


func _with_share(d: AssaultDirector, share: float) -> void:
	var tw: DirectorTweak = d.tweak.duplicate() as DirectorTweak
	tw.assault_special_share = PackedFloat32Array([share, share, share])
	d.tweak = tw


func _is_special(d: AssaultDirector, id: StringName) -> bool:
	var def: EnemyDef = d.roster.enemy_def(id)
	return def != null and def.is_special


func test_share_rate_and_only_specials_added() -> void:
	var d: AssaultDirector = await _director()
	var shares: PackedFloat32Array = d.tweak.assault_special_share
	assert_eq(shares.size(), 3, "one share per stage")
	for i: int in shares.size() - 1:
		assert_true(shares[i + 1] >= shares[i], "later stages carry more specials")
	var hits: int = 0
	for i: int in PICKS:
		var extra: Array[StringName] = d._assault_specials()
		if not extra.is_empty():
			hits += 1
		for id: StringName in extra:
			assert_true(_is_special(d, id), "only specials are added (%s)" % id)
	var want: float = shares[clampi(d.stage(), 0, shares.size() - 1)]
	assert_near(float(hits) / PICKS, want, 0.07, "specials added on ~share of the picks (%d/%d)" % [hits, PICKS])


func test_specials_are_added_on_top_of_the_plain_squad() -> void:
	var d: AssaultDirector = await _director()
	_with_share(d, 1.0)
	for k: int in 20:
		d._queue.clear()
		d._queue_index = 0
		d._enqueue_assault()
		var q: Array[StringName] = d._queue.duplicate()
		var n: int = 0
		while n < q.size() and _is_special(d, q[n]):
			n += 1
		assert_true(n > 0, "share 1: specials in front (%s)" % [q])
		# Behind the added specials, a whole plain squad (its own leading specials, if any, read as part of the prefix).
		var whole: bool = false
		for g: SpawnGroupDef in d.tweak.assault_groups:
			var units: Array[StringName] = g.expanded_units() if g != null else ([] as Array[StringName])
			if not units.is_empty() and units.size() <= q.size() and q.slice(q.size() - units.size()) == units:
				whole = true
		assert_true(whole, "a whole plain squad rides behind the specials (%s)" % [q])


func test_capped_specials_are_not_rolled() -> void:
	var d: AssaultDirector = await _director()
	_with_share(d, 1.0)
	for i: int in 50:
		for id: StringName in d._assault_specials():
			assert_true(d.roster.can_spawn_special(d.roster.enemy_def(id)), "%s under its cap" % id)


func test_control_specials_rarer_than_assault() -> void:
	var d: AssaultDirector = await _director()
	assert_true(d.tweak.control_special_chance < d.tweak.assault_special_share[0],
		"between waves rolls specials less often than an assault pick")
