## D-125 (B's weapon balance audit): the Wrecker's HP grows x5 from Routine to Cataclysm (was x12), close to the
## other units' curve. Pins the table, its ratio to the TAC Heavy, and the PD2-shaped budget: a stock Corsair AR
## can kill a Cataclysm Wrecker solo through the visor (plates, then head x2.5) in about half its reserve.
extends TestCase

const TABLE: Array[float] = [2000.0, 2000.0, 3000.0, 4500.0, 7000.0, 10000.0]
const WRECKER: String = "res://systems/ai/data/enemies/wrecker.tres"


func test_table_per_variant() -> void:
	for id: String in ["wrecker", "wrecker_g", "wrecker_b", "wrecker_s", "wrecker_m"]:
		var d: EnemyDef = load("res://systems/ai/data/enemies/%s.tres" % id) as EnemyDef
		var mult: float = 2.0 if id == "wrecker_m" else 1.0
		assert_eq(d.health.size(), TABLE.size(), "%s: one HP per Difficulty" % id)
		for i: int in TABLE.size():
			assert_near(d.health[i], TABLE[i] * mult, 0.01, "%s HP[%d]" % [id, i])


func test_ratio_to_the_heavy() -> void:
	var w: EnemyDef = load(WRECKER) as EnemyDef
	var h: EnemyDef = load("res://systems/ai/data/enemies/tac_heavy.tres") as EnemyDef
	var last: int = w.health.size() - 1
	assert_near(w.health[last] / w.health[0], 5.0, 0.001, "x5 Routine -> Cataclysm")
	# D-127: the Heavy got +25 % HP (200..800), so the ratio reads 10 -> 12.5 (it was 12.5 -> 15.6 under D-125 alone).
	assert_near(w.health[0] / h.health[0], 10.0, 0.01, "10x the Heavy on Routine")
	assert_near(w.health[last] / h.health[last], 12.5, 0.01, "12.5x the Heavy on Cataclysm")
	for i: int in w.health.size():
		var r: float = w.health[i] / h.health[i]
		assert_true(r >= 9.5 and r <= 13.0, "Wrecker:Heavy ratio stays 9.5-13 (Difficulty %d: %.2f)" % [i, r])


func test_corsair_head_route_budget() -> void:
	var w: EnemyDef = load(WRECKER) as EnemyDef
	var gun: WeaponDef = load("res://content/data/weapons/corsair_ar.tres") as WeaponDef
	var dmg: float = gun.base.damage
	var reserve: int = gun.base.total_ammo
	assert_true(dmg > 0.0 and reserve > 0, "Corsair stats readable")
	var plates: Array = w.params["plate_health"]
	var rounds: int = 0
	for p: Variant in plates:  # each bullet takes x1 off the current plate; overflow is lost
		rounds += ceili(float(p) / dmg)
	var hp: float = w.health[w.health.size() - 1]
	rounds += ceili(hp / (dmg * w.headshot_mult[w.headshot_mult.size() - 1]))
	assert_true(rounds <= reserve, "a Corsair can solo a Cataclysm Wrecker via the visor (%d of %d)" % [rounds, reserve])
	assert_true(rounds >= reserve / 3, "but it costs a real share of the reserve (%d of %d)" % [rounds, reserve])
	assert_true(ceili(hp / dmg) > reserve, "body fire alone still can't (%d > %d)" % [ceili(hp / dmg), reserve])
