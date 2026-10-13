## Lead D-082 queue item 2 (PP-B-5): the stats the loadout / workshop panels show (StatCalculator.display
## of LoadoutResolver.resolve_weapon) match what ENV A's CrewWeapons actually uses in play, for every
## weapon, stock and with each of its mods: damage per shot (all pellets), fire rate (shot interval),
## magazine, total ammo (mag + reserve on arming) and the tactical / empty reload times.
## No modifiers (skills) apply here: the panels show the weapon, skills apply in play.
extends TestCase


func _check(def: WeaponDef, mods: Array[StringName], bad: Array[String]) -> void:
	var st: WeaponStats = LoadoutResolver.resolve_weapon(def.id, mods)
	if st == null:
		bad.append("%s %s: no stats" % [def.id, mods])
		return
	var shown: Dictionary = StatCalculator.display(st)
	var l: Loadout = Loadout.new()
	var ws: int = Enums.WeaponSlot.PRIMARY if def.slot == Enums.WeaponSlot.PRIMARY else Enums.WeaponSlot.SECONDARY
	if ws == Enums.WeaponSlot.PRIMARY:
		l.primary = def.id
		l.primary_mods = mods
	else:
		l.secondary = def.id
		l.secondary_mods = mods
	l = LoadoutResolver.resolve(l)
	var cw: CrewWeapons = CrewWeapons.new()
	cw.set_loadout(l)
	var gs: WeaponStats = cw.stats(ws)
	var tag: String = "%s %s" % [def.id, mods]
	if gs == null:
		bad.append(tag + ": CrewWeapons has no stats")
		cw.free()
		return
	var pellets: int = maxi(gs.pellets, 1)
	var checks: Array = [
		["mag", int(shown["mag"]), cw.mag_size(ws)],
		["total_ammo", int(shown["total_ammo"]), cw.mag(ws) + cw.reserve(ws)],
		["rof (shot interval s)", 60.0 / maxf(float(shown["rof"]), 1.0), 60.0 / maxf(gs.fire_rate_rpm, 1.0)],
		["reload", float(shown["reload"]), gs.reload_time_s],
		["reload_empty", float(shown["reload_empty"]), gs.reload_empty_time_s],
		["damage per shot", float(shown["damage"]), snappedf(cw.damage_at(ws, 0.0) * pellets, 0.1)],
	]
	for c: Array in checks:
		if absf(float(c[1]) - float(c[2])) > 0.051:
			bad.append("%s %s: UI %s vs play %s" % [tag, c[0], c[1], c[2]])
	cw.free()


func test_ui_stats_match_gameplay_for_every_weapon() -> void:
	var bad: Array[String] = []
	var n: int = 0
	for w: Variant in ContentDB.all_weapons():
		var def: WeaponDef = w as WeaponDef
		if def == null or def.base == null:
			continue
		_check(def, [] as Array[StringName], bad)
		n += 1
		for slot: Variant in def.mod_slots:
			for mod_id: Variant in def.mod_slots[slot]:
				_check(def, [StringName(mod_id)] as Array[StringName], bad)
				n += 1
	assert_true(n > 30, "checked %d builds" % n)
	assert_eq(bad.size(), 0, "UI vs gameplay stat mismatches:\n" + "\n".join(bad))
