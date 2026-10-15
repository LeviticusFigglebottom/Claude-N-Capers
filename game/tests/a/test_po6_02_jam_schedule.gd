## PO6-02 / D-114 §2 (S9.3): drill/saw/thermal jam schedule over 1000 seeds: mean ≤ 1.5 jams, max 2,
## never in the first or last 10 % of progress, points ascending and spaced.
extends TestCase

const SEEDS: int = 1000


func test_po6_02_jam_schedule_1000_seeds() -> void:
	var tw: InteractionTweak = Tweak.interaction()
	var total: int = 0
	var worst: int = 0
	var bad_range: int = 0
	var bad_gap: int = 0
	for s: int in range(1, SEEDS + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var pts: Array[float] = DeviceRunner.roll_jam_points(rng, tw, 1.0)
		total += pts.size()
		worst = maxi(worst, pts.size())
		for i: int in range(pts.size()):
			if pts[i] < 0.1 or pts[i] > 0.9:
				bad_range += 1
			if i > 0 and pts[i] - pts[i - 1] < tw.device_jam_min_gap - 0.0001:
				bad_gap += 1
	var mean: float = float(total) / SEEDS
	assert_true(mean <= 1.5, "mean jams %.3f <= 1.5" % mean)
	assert_true(mean >= 1.0, "mean jams %.3f >= 1 (a standard drill still jams)" % mean)
	assert_true(worst <= 2, "max jams %d <= 2" % worst)
	assert_eq(bad_range, 0, "no jam in the first/last 10 %")
	assert_eq(bad_gap, 0, "jams spaced by device_jam_min_gap")


func test_po6_02_jam_chance_mult_reduces_jams() -> void:
	var tw: InteractionTweak = Tweak.interaction()
	var full: int = 0
	var half: int = 0
	for s: int in range(1, SEEDS + 1):
		var a := RandomNumberGenerator.new()
		a.seed = s
		full += DeviceRunner.roll_jam_points(a, tw, 1.0).size()
		var b := RandomNumberGenerator.new()
		b.seed = s
		half += DeviceRunner.roll_jam_points(b, tw, 0.5).size()
	assert_true(half < full, "jam chance 0.5 jams less (%d < %d)" % [half, full])
	var none := RandomNumberGenerator.new()
	none.seed = 7
	assert_eq(DeviceRunner.roll_jam_points(none, tw, 0.0).size(), 0, "jam chance 0 -> no jams")
