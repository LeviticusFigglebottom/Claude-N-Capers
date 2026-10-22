## PO-17 (D-145 §2, PO: "loud is too hard on lower difficulties"): Routine ~ PD2 Normal, Tense ~ PD2 Hard, Hazardous+
## unchanged. Pins ENV A's levers: police damage per hit (EnemyDef), NPC hit chance per difficulty (CombatTweak), and
## the director's low-tier multipliers (force pool, refill cadence, special share; DirectorTweak). Pure data, plus a
## bare AssaultDirector (no heist) for the force pool / refill arithmetic.
extends TestCase

const DIR: String = "res://systems/ai/data/enemies/"
const DIRECTOR_TWEAK: String = "res://systems/director/director_tweak.tres"
## Damage per hit, Routine..Cataclysm, after PO-17 (Routine ~x2/3, Tense ~x5/6 of the old Routine/Tense; Hazardous+
## as before).
const DAMAGE: Dictionary = {
	"security_officer": [7.0, 8.5, 15.0, 20.0, 30.0, 40.0],
	"patrol_officer": [7.0, 8.5, 15.0, 20.0, 30.0, 40.0],
	"tac_light": [6.0, 8.0, 22.5, 30.0, 45.0, 60.0],  # D-145 Tense vs PD2 Hard (rifle SWAT ~8)
	"frd/tac_light": [10.0, 12.5, 22.5, 30.0, 45.0, 60.0],
	"sentinel/tac_light": [10.0, 12.5, 22.5, 30.0, 45.0, 60.0],
	"zero/tac_light": [10.0, 12.5, 22.5, 30.0, 45.0, 60.0],
	"tac_heavy": [13.5, 17.0, 30.0, 40.0, 60.0, 80.0],
	"frd_agent": [8.0, 10.0, 18.0, 24.0, 36.0, 48.0],
	"sentinel/frd_agent": [8.0, 10.0, 18.0, 24.0, 36.0, 48.0],
	"cartel_gunman": [8.0, 10.0, 18.0, 25.0, 35.0, 45.0],
	"bulwark": [7.0, 8.5, 15.0, 20.0, 30.0, 40.0],
	"stinger": [6.0, 8.0, 22.5, 30.0, 45.0, 60.0],  # D-145 (PD2 taser 8-10)
	"longshot": [60.0, 90.0, 160.0, 200.0, 220.0, 240.0],
}
const HIT_MULT: Array[float] = [0.65, 0.8, 1.05, 1.1, 1.15, 1.2]


func _def(id: String) -> EnemyDef:
	return load(DIR + id + ".tres") as EnemyDef


func test_damage_table() -> void:
	for id: String in DAMAGE:
		var d: EnemyDef = _def(id)
		var want: Array = DAMAGE[id]
		assert_eq(d.damage.size(), want.size(), "%s: one damage per Difficulty" % id)
		for i: int in want.size():
			assert_near(d.damage[i], float(want[i]), 0.001, "%s damage[%d]" % [id, i])
		assert_true(d.damage[0] < d.damage[1] and d.damage[1] < d.damage[2],
			"%s: Routine < Tense < Hazardous" % id)


func test_hit_chance_per_difficulty() -> void:
	var tw: CombatTweak = CombatTweak.data()
	assert_eq(tw.npc_hit_chance_mult.size(), HIT_MULT.size(), "one mult per Difficulty")
	for i: int in HIT_MULT.size():
		assert_near(tw.npc_hit_chance_mult[i], HIT_MULT[i], 0.0001, "hit mult[%d]" % i)
	# At 15 m the curve gives 0.6: Routine 0.39, Tense 0.48, Hazardous 0.63 (unchanged).
	assert_near(tw.npc_hit_chance(15.0, Enums.Difficulty.ROUTINE), 0.39, 0.001, "Routine at 15 m")
	assert_near(tw.npc_hit_chance(15.0, Enums.Difficulty.TENSE), 0.48, 0.001, "Tense at 15 m")
	assert_near(tw.npc_hit_chance(15.0, Enums.Difficulty.HAZARDOUS), 0.63, 0.001, "Hazardous at 15 m")


## Expected incoming fire from a TAC Light at 15 m (damage x hit chance per shot): Routine ~26 % and Tense ~43 % of
## the pre-PO-17 value (15 x 0.6 = 9.0 on both; D-145 Tense vs PD2 Hard: 6 / 8 per hit), Hazardous unchanged.
func test_expected_damage_per_shot_ratio() -> void:
	var tw: CombatTweak = CombatTweak.data()
	var d: EnemyDef = _def("tac_light")
	var old: float = 15.0 * 0.6
	var r: float = d.damage[0] * tw.npc_hit_chance(15.0, Enums.Difficulty.ROUTINE) / old
	var t: float = d.damage[1] * tw.npc_hit_chance(15.0, Enums.Difficulty.TENSE) / old
	assert_true(r > 0.23 and r < 0.29, "Routine ~0.26 of before (%.3f)" % r)
	assert_true(t > 0.4 and t < 0.46, "Tense ~0.43 of before (%.3f)" % t)
	var h: float = d.damage[2] * tw.npc_hit_chance(15.0, Enums.Difficulty.HAZARDOUS)
	assert_near(h, 22.5 * 0.63, 0.001, "Hazardous unchanged")


func test_director_low_tier_multipliers() -> void:
	var tw: DirectorTweak = load(DIRECTOR_TWEAK) as DirectorTweak
	var want: Dictionary = {
		"force_pool_difficulty_mult": [0.6, 0.8], "refill_interval_difficulty_mult": [2.0, 1.5],
		"special_share_difficulty_mult": [0.35, 0.6],  # D-154 (was 0.5 / 0.75)
	}
	for prop: String in want:
		var arr: PackedFloat32Array = tw.get(prop) as PackedFloat32Array
		assert_eq(arr.size(), 6, "%s: one per Difficulty" % prop)
		assert_near(DirectorTweak.by_difficulty(arr, Enums.Difficulty.ROUTINE), float(want[prop][0]), 0.0001,
			"%s Routine" % prop)
		assert_near(DirectorTweak.by_difficulty(arr, Enums.Difficulty.TENSE), float(want[prop][1]), 0.0001,
			"%s Tense" % prop)
		for d: int in range(Enums.Difficulty.HAZARDOUS, 6):
			assert_near(DirectorTweak.by_difficulty(arr, d), 1.0, 0.0001, "%s difficulty %d unchanged" % [prop, d])
	assert_near(DirectorTweak.by_difficulty(PackedFloat32Array(), 3), 1.0, 0.0001, "empty array = 1.0")


## A bare director (no runtime: Routine, enemy_cap 20, solo force crew) applies the Routine multipliers.
func test_director_applies_them() -> void:
	var d: AssaultDirector = AssaultDirector.new()
	d.tweak = load(DIRECTOR_TWEAK) as DirectorTweak
	var full: int = d._force_cap_at(d.tweak.stage_force_mult.size() - 1)
	assert_eq(d._force_pool(1), ceili(float(full) * d.tweak.force_pool_per_force[0] * 0.6), "Routine force pool x0.6")
	assert_near(d._refill_interval(), d.tweak.assault_refill_interval_s * 2.0, 0.0001, "Routine refill x2")
	d.free()
