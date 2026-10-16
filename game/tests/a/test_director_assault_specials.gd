## Round-227 P3 red (LEAD): PD2 brings specials mostly WITH the assault. Each BUILD/SUSTAIN group pick draws from the
## special-carrying assault groups with DirectorTweak.assault_special_share[stage]; the between-wave CONTROL roll
## stays rarer. Statistical over many picks on the real tweak (seeded, deterministic).
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
	return _rt.service(G.SVC_DIRECTOR) as AssaultDirector


func _special_share(d: AssaultDirector, phase: int, n: int) -> float:
	d.assault_phase = phase as Enums.AssaultPhase
	var hits: int = 0
	for i: int in n:
		var g: SpawnGroupDef = d._pick_assault_group()
		if g != null and d._carries_special(g):
			hits += 1
	return float(hits) / float(n)


func test_assault_picks_carry_specials_at_least_the_share() -> void:
	var d: AssaultDirector = await _director()
	var shares: PackedFloat32Array = d.tweak.assault_special_share
	assert_eq(shares.size(), 3, "one share per stage")
	for i: int in shares.size() - 1:
		assert_true(shares[i + 1] >= shares[i], "later stages carry more specials")
	var got: float = _special_share(d, Enums.AssaultPhase.SUSTAIN, PICKS)
	var floor_share: float = shares[clampi(d.stage(), 0, shares.size() - 1)]
	assert_true(got >= floor_share - 0.06, "SUSTAIN picks with a special: %.2f (share %.2f + the plain picks')" % [
		got, floor_share])


func test_no_share_falls_back_to_the_plain_pick() -> void:
	var d: AssaultDirector = await _director()
	var tw: DirectorTweak = d.tweak.duplicate() as DirectorTweak
	tw.assault_special_share = PackedFloat32Array([0.0, 0.0, 0.0])
	d.tweak = tw
	var plain: float = _special_share(d, Enums.AssaultPhase.SUSTAIN, PICKS)
	tw.assault_special_share = PackedFloat32Array([1.0, 1.0, 1.0])
	var all: float = _special_share(d, Enums.AssaultPhase.SUSTAIN, PICKS)
	assert_near(all, 1.0, 0.0001, "share 1: every pick carries a special (none capped yet)")
	assert_true(plain < all, "the share raises specials above the plain weighted pick (%.2f -> %.2f)" % [plain, all])


func test_control_specials_rarer_than_assault() -> void:
	var d: AssaultDirector = await _director()
	assert_true(d.tweak.control_special_chance < d.tweak.assault_special_share[0],
		"between waves rolls specials less often than an assault pick")
