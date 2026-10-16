## P's scoped ADS (LEAD r226, data_schemas v1.2): every sight mod carries WeaponStats.is_scope / scope_reticle /
## scope_reticle_color in its delta. A magnified optic (>= 3.5x) is a scope (P's overlay); a scope magnifies;
## reticle ids come from the overlay's set; the snipers' stock builds (default_mods) resolve to a scope.
extends TestCase

const SCOPE_MIN_MAG: float = 3.5
const RETICLES: Array[StringName] = [&"", &"duplex", &"mildot", &"chevron", &"dot"]
const SNIPERS: Array[StringName] = [&"weapon.heron_308", &"weapon.osprey_762", &"weapon.condor_50"]


func _sights() -> Array[WeaponModDef]:
	var out: Array[WeaponModDef] = []
	for m: Variant in ContentDB.all_of(ContentDB.MODS):
		var d: WeaponModDef = m as WeaponModDef
		if d != null and d.delta != null and int(d.mod_type) == int(Enums.ModType.SIGHT):
			out.append(d)
	return out


func test_magnified_sights_are_scopes() -> void:
	var sights: Array[WeaponModDef] = _sights()
	assert_true(sights.size() >= 40, "sight mods checked: %d" % sights.size())
	var scopes: int = 0
	for d: WeaponModDef in sights:
		var s: WeaponStats = d.delta
		if s.magnification >= SCOPE_MIN_MAG:
			assert_true(s.is_scope, "%s (%.1fx) is a scope" % [d.id, s.magnification])
		if s.is_scope:
			scopes += 1
			assert_true(s.magnification > 1.0, "%s: a scope magnifies (%.1fx)" % [d.id, s.magnification])
		assert_has(RETICLES, s.scope_reticle, "%s reticle id" % d.id)
	assert_eq(scopes, 6, "osprey 4x/8x, heron 4x/10x, condor 6x/12x")


func test_lit_reticles_and_the_farsight_fix() -> void:
	var heron10: WeaponModDef = ContentDB.mod(&"mod.heron_scope_10x")
	assert_near(heron10.delta.magnification, 10.0, 0.001, "Farsight 10x Scope is 10x")
	for d: WeaponModDef in _sights():
		if String(d.id).ends_with("reflex_sight"):
			assert_eq(d.delta.scope_reticle, &"dot", "%s: red dot" % d.id)
			assert_true(d.delta.scope_reticle_color.a > 0.0, "%s: illuminated" % d.id)
	assert_false(ContentDB.mod(&"mod.rail_prism_scope").delta.is_scope, "3x prism stays see-through (LEAD r226)")
	assert_false(ContentDB.mod(&"mod.shrike_scout_scope").delta.is_scope, "3x scout stays see-through")


func test_sniper_stock_builds_resolve_to_a_scope() -> void:
	for id: StringName in SNIPERS:
		var w: WeaponDef = ContentDB.weapon(id)
		var mods: Array[StringName] = []
		for t: Variant in w.default_mods:
			mods.append(StringName(w.default_mods[t]))
		var st: WeaponStats = LoadoutResolver.resolve_weapon(id, mods)
		assert_true(st.is_scope, "%s stock build is scoped" % id)
		assert_true(st.magnification >= SCOPE_MIN_MAG, "%s magnifies" % id)
		assert_ne(st.scope_reticle, &"", "%s has a reticle" % id)
	var iron: WeaponStats = LoadoutResolver.resolve_weapon(&"weapon.corsair_ar", [] as Array[StringName])
	assert_false(iron.is_scope, "iron sights are not a scope")
