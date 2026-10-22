## D-118: rail gadgets (GADGET -> `SideRail`) and shotgun ammo types (AMMO).
## * Every conventional weapon with a `SideRail` offers mod.rail_laser / rail_flashlight / rail_combo; the specials
##   (bow, crossbow, flamethrower, launcher, saw, rotary) do not.
## * Every gadget scene ships its origin marker(s) (ENV P: `LaserOrigin`, `LightOrigin`), local -Z = weapon forward,
##   standalone and attached on every weapon; WeaponVisual.get_marker() finds them.
## * Resolved WeaponStats.gadgets lists the gadget kinds; concealment / hip-spread deltas land.
## * The five shotguns offer the four ammo types; SpecialWeapons.params_of (D-057 mod params merge) carries
##   `ammo_type` and the D-118 keys exactly; the stat deltas point the PD2 way.
## * AMMO never puts a mesh on a WeaponVisual (no attach marker; its model is an icon).
extends TestCase

const LASER: StringName = &"mod.rail_laser"
const LIGHT: StringName = &"mod.rail_flashlight"
const COMBO: StringName = &"mod.rail_combo"
const GADGETS: Array[StringName] = [LASER, LIGHT, COMBO]
## Special weapons left without gadgets (their SideRail, if any, is not a gadget rail).
const SPECIALS: Array[StringName] = [
	&"weapon.thorn_bow", &"weapon.vise_crossbow", &"weapon.furnace_ft", &"weapon.thumper_40",
	&"weapon.rotor_saw", &"weapon.cyclone_rotary",
]
## Gadget mod -> {marker name -> expected}: which origin markers its scene carries.
const MARKERS: Dictionary = {
	LASER: {&"LaserOrigin": true, &"LightOrigin": false},
	LIGHT: {&"LaserOrigin": false, &"LightOrigin": true},
	COMBO: {&"LaserOrigin": true, &"LightOrigin": true},
}
const GADGET_KINDS: Dictionary = {
	LASER: [&"laser"], LIGHT: [&"flashlight"], COMBO: [&"laser", &"flashlight"],
}
const CONCEALMENT: Dictionary = {LASER: -1, LIGHT: -1, COMBO: -2}
const LASER_PARAMS: Dictionary = {"gadget_laser_color": Color(1, 0.12, 0.1), "gadget_laser_range_m": 50.0}
const LIGHT_PARAMS: Dictionary = {"gadget_light_range_m": 25.0, "gadget_light_angle_deg": 30.0, "gadget_light_energy": 2.0}

const SHOTGUNS: Array[StringName] = [
	&"weapon.plowman_12", &"weapon.brute_12", &"weapon.harrow_12", &"weapon.mule_12", &"weapon.reaper_db",
]
const SLUG: StringName = &"mod.shotgun_slug"
const HE: StringName = &"mod.shotgun_he"
const FLECHETTE: StringName = &"mod.shotgun_flechette"
const DRAGON: StringName = &"mod.shotgun_dragons_breath"
const AMMO: Array[StringName] = [SLUG, HE, FLECHETTE, DRAGON]
## D-118 params, exactly.
const AMMO_PARAMS: Dictionary = {
	SLUG: {"ammo_type": &"slug", "pellets": 1, "armor_pierce": 1.0, "shield_pierce": true, "ammo_pickup_mult": 0.7},
	HE: {"ammo_type": &"he", "pellets": 1, "explosion_radius_m": 2.0, "explosion_damage_mult": 1.0,
		"penetration": false, "ammo_pickup_mult": 0.7},
	FLECHETTE: {"ammo_type": &"flechette", "pellets_mult": 1.5, "dot_dps": 4.0, "dot_s": 3.0, "ammo_pickup_mult": 0.9},
	DRAGON: {"ammo_type": &"dragons_breath", "dot_dps": 8.0, "dot_s": 3.0, "ignite": true, "panic_civilians": true,
		"range_mult": 0.7, "ammo_pickup_mult": 0.8},
}


func before_all() -> void:
	ContentDB.clear_cache()


func _has_side_rail(w: WeaponDef) -> bool:
	var inst: Node = w.model.instantiate()
	var ok: bool = inst.find_child("SideRail", true, false) != null
	inst.free()
	return ok


## Gadget kinds as a plain string list (typed / untyped arrays compare alike).
func _names(a: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for g: Variant in a:
		out.append(String(g))
	return out


## Transform of `node` in `root`'s space (works outside the tree).
func _in(root: Node3D, node: Node3D) -> Transform3D:
	return WeaponVisual._transform_to(root, node)


func test_gadget_defs_shape_and_strings() -> void:
	for id: StringName in GADGETS:
		var m: WeaponModDef = ContentDB.mod(id)
		assert_true(m != null, "%s exists" % id)
		if m == null:
			continue
		assert_eq(m.mod_type, Enums.ModType.GADGET, "%s is a GADGET" % id)
		assert_true(m.model != null, "%s has a model" % id)
		assert_true(m.price > 0 and m.unlock == &"", "%s priced, unlocked" % id)
		assert_eq(m.delta.concealment, int(CONCEALMENT[id]), "%s concealment" % id)
		assert_eq(_names(m.delta.gadgets), _names(GADGET_KINDS[id]), "%s delta gadgets" % id)
		var want: Dictionary = {}
		if (GADGET_KINDS[id] as Array).has(&"laser"):
			want.merge(LASER_PARAMS)
		if (GADGET_KINDS[id] as Array).has(&"flashlight"):
			want.merge(LIGHT_PARAMS)
		assert_eq(m.params.size(), want.size(), "%s params keys: %s" % [id, m.params.keys()])
		for k: String in want:
			assert_true(m.params.has(k), "%s params.%s" % [id, k])
			if want[k] is Color:
				assert_true((m.params.get(k, Color()) as Color).is_equal_approx(want[k]), "%s %s" % [id, k])
			else:
				assert_near(float(m.params.get(k, 0.0)), float(want[k]), 0.0001, "%s %s" % [id, k])
		for suffix: String in [".name", ".desc"]:
			var key: String = "item.%s%s" % [id, suffix]
			assert_ne(UiText.t(StringName(key)), key, "%s string" % key)


func test_every_conventional_weapon_with_a_side_rail_offers_the_gadgets() -> void:
	var offered: int = 0
	for w: WeaponDef in ContentDB.all_weapons():
		var slot: Array = w.mod_slots.get(Enums.ModType.GADGET, [])
		if SPECIALS.has(w.id):
			assert_true(slot.is_empty(), "%s (special) has no gadget slot" % w.id)
			continue
		if not _has_side_rail(w):
			continue
		for id: StringName in GADGETS:
			assert_true(slot.has(id), "%s offers %s" % [w.id, id])
		offered += 1
	assert_true(offered >= 25, "gadgets on the conventional armory (%d weapons)" % offered)


## ENV P: each gadget scene carries its origin markers; -Z = beam / cone axis = forward (Godot -Z).
func test_gadget_scenes_ship_origin_markers() -> void:
	for id: StringName in GADGETS:
		var m: WeaponModDef = ContentDB.mod(id)
		var inst: Node3D = m.model.instantiate() as Node3D
		for marker: StringName in MARKERS[id]:
			var n: Node3D = inst.find_child(String(marker), true, false) as Node3D
			if not bool(MARKERS[id][marker]):
				assert_true(n == null, "%s has no %s" % [id, marker])
				continue
			assert_true(n != null, "%s ships %s" % [id, marker])
			if n == null:
				continue
			var xf: Transform3D = _in(inst, n)
			assert_true((-xf.basis.z).normalized().dot(Vector3.FORWARD) > 0.999, "%s %s -Z forward" % [id, marker])
			# at the front face of the unit: nothing of the gadget's own body lies ahead of the emitter
			assert_true(xf.origin.z < -0.02, "%s %s at the front (z %.3f)" % [id, marker, xf.origin.z])
			assert_true(xf.origin.x > 0.005, "%s %s off the rail face (x %.3f)" % [id, marker, xf.origin.x])
		inst.free()


## Attached on every weapon: under SideRail, origin markers still look down the bore, reachable via get_marker().
func test_gadgets_attach_on_every_weapon_and_point_forward() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		if not w.mod_slots.has(Enums.ModType.GADGET):
			continue
		for id: StringName in GADGETS:
			var v: WeaponVisual = WeaponVisual.new()
			add_child(v)
			v.setup_ids(w.id, [id] as Array[StringName])
			var inst: Node3D = v.attached.get(Enums.ModType.GADGET)
			assert_true(inst != null, "%s attaches %s" % [w.id, id])
			if inst == null:
				v.queue_free()
				continue
			assert_eq(inst.get_parent(), v.get_base_marker(&"SideRail"), "%s: %s under SideRail" % [w.id, id])
			var muzzle: Node3D = v.get_marker(&"Muzzle")
			for marker: StringName in MARKERS[id]:
				if not bool(MARKERS[id][marker]):
					continue
				var n: Node3D = v.get_marker(marker)
				assert_true(n != null and inst.is_ancestor_of(n), "%s: get_marker(%s) is the gadget's" % [w.id, marker])
				if n == null:
					continue
				var fwd: Vector3 = (-n.global_basis.z).normalized()
				assert_true(fwd.dot(Vector3.FORWARD) > 0.999, "%s: %s %s along the bore (%s)" % [w.id, id, marker, fwd])
				assert_true(n.global_position.z > muzzle.global_position.z - 0.06,
					"%s: %s %s not far past the muzzle" % [w.id, id, marker])
				# pistols (SideRail = the dust-cover rail, shared with Underbarrel): the unit hangs UNDER the barrel
				var under: Node3D = v.get_base_marker(&"Underbarrel")
				if under != null and under.global_position.distance_to(inst.get_parent().global_position) < 0.001:
					assert_true(n.global_position.y < under.global_position.y - 0.005,
						"%s: %s %s under the dust-cover rail" % [w.id, id, marker])
					assert_true(absf(n.global_position.x) < 0.02, "%s: %s %s on the centreline" % [w.id, id, marker])
			v.queue_free()


func test_resolved_gadgets_and_deltas() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		if not w.mod_slots.has(Enums.ModType.GADGET):
			continue
		var stock: WeaponStats = LoadoutResolver.resolve_weapon(w.id, [] as Array[StringName])
		assert_true(stock.gadgets.is_empty(), "%s: no gadget without the mod" % w.id)
		for id: StringName in GADGETS:
			var s: WeaponStats = LoadoutResolver.resolve_weapon(w.id, [id] as Array[StringName])
			assert_eq(_names(s.gadgets), _names(GADGET_KINDS[id]), "%s + %s gadgets" % [w.id, id])
			var floor_c: int = LoadoutResolver.curve_tweak().weapon_concealment_min
			assert_eq(s.concealment, maxi(stock.concealment + int(CONCEALMENT[id]), floor_c), "%s + %s concealment" % [w.id, id])
			if (GADGET_KINDS[id] as Array).has(&"laser"):
				assert_true(s.spread_deg_hip < stock.spread_deg_hip or stock.spread_deg_hip == 0.0,
					"%s + %s: steadier from the hip" % [w.id, id])
			else:
				assert_eq(s.spread_deg_hip, stock.spread_deg_hip, "%s + %s hip spread unchanged" % [w.id, id])


func test_ammo_defs_shape_and_strings() -> void:
	for id: StringName in AMMO:
		var m: WeaponModDef = ContentDB.mod(id)
		assert_true(m != null, "%s exists" % id)
		if m == null:
			continue
		assert_eq(m.mod_type, Enums.ModType.AMMO, "%s is AMMO" % id)
		assert_true(m.model != null, "%s has an icon model" % id)
		assert_true(m.price > 0 and m.unlock == &"", "%s priced, unlocked" % id)
		assert_eq(m.params.size(), (AMMO_PARAMS[id] as Dictionary).size(), "%s params keys: %s" % [id, m.params.keys()])
		for suffix: String in [".name", ".desc"]:
			var key: String = "item.%s%s" % [id, suffix]
			assert_ne(UiText.t(StringName(key)), key, "%s string" % key)


func test_each_shotgun_offers_the_four_ammo_types() -> void:
	for wid: StringName in SHOTGUNS:
		var w: WeaponDef = ContentDB.weapon(wid)
		assert_true(w != null, "%s exists" % wid)
		if w == null:
			continue
		var slot: Array = w.mod_slots.get(Enums.ModType.AMMO, [])
		for id: StringName in AMMO:
			assert_true(slot.has(id), "%s offers %s" % [wid, id])
		assert_false(w.default_mods.has(Enums.ModType.AMMO), "%s: buckshot is the unmodded load" % wid)
	for w: WeaponDef in ContentDB.all_weapons():
		if not SHOTGUNS.has(w.id):
			assert_false(w.mod_slots.has(Enums.ModType.AMMO) and (w.mod_slots[Enums.ModType.AMMO] as Array).has(SLUG),
				"%s is not a shotgun" % w.id)


## D-057: mod params shallow-merge over WeaponDef.params; the merged dict carries ammo_type + the D-118 keys.
func test_resolved_params_carry_the_ammo_type() -> void:
	for wid: StringName in SHOTGUNS:
		var w: WeaponDef = ContentDB.weapon(wid)
		assert_false(SpecialWeapons.params_of(w).has("ammo_type"), "%s: no ammo_type on buckshot" % wid)
		for id: StringName in AMMO:
			var p: Dictionary = SpecialWeapons.params_of(w, [id] as Array[StringName])
			var want: Dictionary = AMMO_PARAMS[id]
			for k: String in want:
				assert_true(p.has(k), "%s + %s: params.%s" % [wid, id, k])
				var got: Variant = p.get(k)
				if want[k] is StringName or want[k] is bool:
					assert_eq(got, want[k], "%s + %s: %s" % [wid, id, k])
				elif want[k] is int:
					assert_true(got is int and int(got) == int(want[k]), "%s + %s: %s int" % [wid, id, k])
				else:
					assert_near(float(got), float(want[k]), 0.0001, "%s + %s: %s" % [wid, id, k])
			assert_true(p.get("ammo_type") is StringName, "%s + %s: ammo_type is a StringName" % [wid, id])
			assert_eq(SpecialWeapons.kind_of(p), SpecialWeapons.KIND_HITSCAN, "%s + %s stays hitscan" % [wid, id])


## PD2-style stat directions (WeaponStats.damage is per pellet; pellets / falloff are never mod deltas).
func test_ammo_stat_deltas() -> void:
	for wid: StringName in SHOTGUNS:
		var base: WeaponStats = LoadoutResolver.resolve_weapon(wid, [] as Array[StringName])
		var slug: WeaponStats = LoadoutResolver.resolve_weapon(wid, [SLUG] as Array[StringName])
		var he: WeaponStats = LoadoutResolver.resolve_weapon(wid, [HE] as Array[StringName])
		var fl: WeaponStats = LoadoutResolver.resolve_weapon(wid, [FLECHETTE] as Array[StringName])
		var db: WeaponStats = LoadoutResolver.resolve_weapon(wid, [DRAGON] as Array[StringName])
		assert_true(slug.damage > base.damage and slug.spread_deg_ads < base.spread_deg_ads, "%s slug harder + tighter" % wid)
		assert_true(slug.total_ammo < base.total_ammo, "%s slug fewer rounds" % wid)
		assert_true(slug.armor_pierce >= 1.0 and slug.shield_pierce, "%s slug pierces armor + shields" % wid)
		assert_true(he.damage > base.damage and he.spread_deg_ads > base.spread_deg_ads, "%s HE harder, wilder" % wid)
		assert_true(he.total_ammo < base.total_ammo, "%s HE fewer rounds" % wid)
		assert_false(he.shield_pierce, "%s HE does not pierce" % wid)
		assert_true(fl.spread_deg_ads < base.spread_deg_ads, "%s flechette tighter" % wid)
		assert_true(db.damage < base.damage, "%s dragon's breath trades impact for fire" % wid)
		for s: WeaponStats in [slug, he, fl, db]:
			assert_eq(s.pellets, base.pellets, "%s: pellets come from params, not deltas" % wid)
			assert_eq(s.falloff_end_m, base.falloff_end_m, "%s: falloff unchanged by ammo deltas" % wid)
			assert_true(s.gadgets.is_empty(), "%s: ammo adds no gadget" % wid)


## AMMO has no attach marker: equipping it adds no node / mesh to the WeaponVisual (main gun or offhand).
func test_ammo_never_adds_a_visible_mesh() -> void:
	for wid: StringName in SHOTGUNS:
		var stock: WeaponVisual = WeaponVisual.new()
		add_child(stock)
		stock.setup_ids(wid, [] as Array[StringName])
		var stock_meshes: int = stock.find_children("*", "MeshInstance3D", true, false).size()
		for id: StringName in AMMO:
			var v: WeaponVisual = WeaponVisual.new()
			add_child(v)
			v.setup_ids(wid, [id] as Array[StringName])
			assert_eq(v.attached.size(), 0, "%s + %s attaches nothing" % [wid, id])
			assert_eq(v.find_children("*", "MeshInstance3D", true, false).size(), stock_meshes, "%s + %s same meshes" % [wid, id])
			assert_true(v.find_child("Mod_*", true, false) == null, "%s + %s no Mod_ node" % [wid, id])
			v.queue_free()
		stock.queue_free()


## Workshop: GADGET and AMMO slots are listed for a shotgun, with readable slot names.
func test_workshop_lists_gadget_and_ammo_slots() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var wm: WorkshopModel = WorkshopModel.new(p)
	wm.select_weapon(&"weapon.plowman_12")
	var slots: Array[int] = wm.slots()
	assert_true(slots.has(Enums.ModType.GADGET) and slots.has(Enums.ModType.AMMO), "plowman slots %s" % [slots])
	var opts: Array[StringName] = wm.slot_options(Enums.ModType.AMMO)
	for id: StringName in AMMO:
		assert_true(opts.has(id), "AMMO slot lists %s" % id)
	for t: int in [Enums.ModType.GADGET, Enums.ModType.AMMO]:
		var key: StringName = WorkshopScreen._mod_type_key(t)
		assert_ne(UiText.t(key), String(key), "slot name %s" % key)
