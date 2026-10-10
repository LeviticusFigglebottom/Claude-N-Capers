## B1-02: StatCalculator display numbers and green/red deltas.
extends TestCase

const PISTOL: StringName = &"weapon.kestrel_p9"


func _base() -> WeaponStats:
	return ContentDB.weapon(PISTOL).base


func _with(mods: Array[StringName]) -> WeaponStats:
	return LoadoutResolver.resolve_weapon(PISTOL, mods)


func test_display_stock_pistol() -> void:
	var d: Dictionary = StatCalculator.display(_base())
	assert_near(d["damage"], 35.0)
	assert_eq(d["accuracy"], 60, "ADS 1.0 deg on a 0..2.5 deg scale")
	assert_eq(d["stability"], 60, "kick 1.0 + 0.5 * 0.4 on a 0..3 deg scale")
	assert_eq(d["concealment"], 30)
	assert_eq(d["threat"], 8)
	assert_eq(d["mag"], 17)
	assert_eq(d["total_ammo"], 153)
	assert_near(d["rof"], 480.0)
	assert_near(d["reload"], 1.5)
	assert_near(d["reload_empty"], 2.1)


func test_display_clamps() -> void:
	var s: WeaponStats = _base().duplicate() as WeaponStats
	s.spread_deg_ads = 10.0
	s.recoil_kick_deg = -1.0
	s.suppression = 999.0
	var d: Dictionary = StatCalculator.display(s)
	assert_eq(d["accuracy"], 0)
	assert_eq(d["stability"], 100)
	assert_eq(d["threat"], 43)


func test_reflex_sight_improves_accuracy_costs_concealment() -> void:
	var d: Dictionary = StatCalculator.delta(_base(), _with([&"mod.p9_reflex_sight"] as Array[StringName]))
	assert_eq(d["accuracy"]["modded"], 66)
	assert_true(d["accuracy"]["better"])
	assert_true(d["concealment"]["changed"])
	assert_false(d["concealment"]["better"])
	assert_false(d["damage"]["changed"])


func test_suppressor_delta_red_concealment_and_threat() -> void:
	var d: Dictionary = StatCalculator.delta(_base(), _with([&"mod.p9_suppressor"] as Array[StringName]))
	assert_eq(d["threat"]["modded"], 0, "suppressed weapons have 0 threat (L3.5)")
	assert_false(d["threat"]["better"])
	assert_false(d["concealment"]["better"])
	assert_false(d["damage"]["better"])
	assert_true(d["stability"]["better"])


func test_extended_mag_delta_reload_is_lower_is_better() -> void:
	var d: Dictionary = StatCalculator.delta(_base(), _with([&"mod.p9_extended_mag"] as Array[StringName]))
	assert_true(d["mag"]["better"])
	assert_eq(d["mag"]["diff"], 8.0)
	assert_true(d["reload"]["changed"])
	assert_false(d["reload"]["better"], "longer reload is red")
	assert_false(d["concealment"]["better"])
