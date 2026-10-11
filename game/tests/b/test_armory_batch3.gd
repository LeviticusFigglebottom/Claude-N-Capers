## B4-18: armory batch 3, the last 19 weapons of the P5 launch armory (pd2_fidelity P5: 6 pistols, 6 SMGs,
## 6 ARs, 5 shotguns, 3 LMGs, 4 snipers, 6 specials incl. a bow, a launcher and a flamethrower). Class
## shapes per L3.2/L3.4, ENV D's existing clip limits for weapons on existing sets (test_armory_batch2), the
## special mechanics expressed with existing WeaponStats fields only (B4-18 questions for ENV A are listed in
## content/data/README.md). The new viewmodel sets (break_action, lever, bow, crossbow, launcher,
## flamethrower, saw, minigun) are ENV D's to build; these tests check data only, never animation libraries.
extends TestCase

const BATCH3: Array[StringName] = [
	&"weapon.wren_380", &"weapon.ferret_9", &"weapon.lancet_45", &"weapon.hush_9", &"weapon.tern_556",
	&"weapon.bastion_br", &"weapon.lark_carbine", &"weapon.harrow_12", &"weapon.brute_12", &"weapon.reaper_db",
	&"weapon.gale_mg", &"weapon.osprey_762", &"weapon.shrike_44", &"weapon.thorn_bow", &"weapon.vise_crossbow",
	&"weapon.thumper_40", &"weapon.furnace_ft", &"weapon.rotor_saw", &"weapon.cyclone_rotary",
]
const MAKERS: Array[String] = [
	"Halvard Arms", "Marrow & Kell", "Brannock Defense", "Tillman Ironworks", "Graff-Lindqvist",
]
## pd2_fidelity P5 launch target per class.
const TARGET: Dictionary = {
	Enums.WeaponClass.PISTOL: 6, Enums.WeaponClass.SMG: 6, Enums.WeaponClass.ASSAULT_RIFLE: 6,
	Enums.WeaponClass.SHOTGUN: 5, Enums.WeaponClass.LMG: 3, Enums.WeaponClass.SNIPER: 4,
	Enums.WeaponClass.SPECIAL: 6,
}
## New viewmodel sets requested from ENV D (B4-18) and the weapon on each.
const NEW_SETS: Dictionary = {
	&"break_action": &"weapon.reaper_db", &"lever": &"weapon.shrike_44", &"bow": &"weapon.thorn_bow",
	&"crossbow": &"weapon.vise_crossbow", &"launcher": &"weapon.thumper_40", &"flamethrower": &"weapon.furnace_ft",
	&"saw": &"weapon.rotor_saw", &"minigun": &"weapon.cyclone_rotary",
}


func before_all() -> void:
	ContentDB.clear_cache()


func _w(id: StringName) -> WeaponDef:
	return ContentDB.weapon(id)


func test_batch_exists_and_completes_the_launch_armory() -> void:
	for id: StringName in BATCH3:
		var w: WeaponDef = _w(id)
		assert_true(w != null, "%s exists" % id)
		if w == null:
			continue
		assert_has(MAKERS, w.manufacturer, "%s maker" % id)
		assert_true(w.display_name != "" and w.model != null, "%s name + model" % id)
	var count: Dictionary = {}
	for w: WeaponDef in ContentDB.all_weapons():
		count[int(w.weapon_class)] = int(count.get(int(w.weapon_class), 0)) + 1
	for c: int in TARGET:
		assert_eq(int(count.get(c, 0)), int(TARGET[c]), "P5 target for %s" % Enums.WeaponClass.keys()[c])
	assert_eq(ContentDB.all_weapons().size(), 36, "36-weapon launch armory")


## Each new set has its weapon; batch-3 weapons without a suppressor slot leave fire_cue_suppressed empty, so
## ENV C registers suppressed variants only where a can fits (the inherently silent ones fall back to the
## anim-set pattern in CuePlayer).
func test_new_anim_sets_and_cues() -> void:
	for set_name: StringName in NEW_SETS:
		assert_eq(_w(NEW_SETS[set_name]).anim_set, set_name, "%s uses %s" % [NEW_SETS[set_name], set_name])
	for id: StringName in BATCH3:
		var w: WeaponDef = _w(id)
		if not w.mod_slots.has(Enums.ModType.SUPPRESSOR):
			assert_eq(w.fire_cue_suppressed, &"", "%s has no suppressor slot" % id)
		else:
			assert_ne(w.fire_cue_suppressed, &"", "%s suppressed cue" % id)


func test_pistol_smg_and_rifle_shapes() -> void:
	var wren: WeaponStats = _w(&"weapon.wren_380").base
	assert_true(wren.mag_size < _w(&"weapon.kestrel_p9").base.mag_size and wren.concealment == 30, "pocket pistol")
	assert_true(wren.damage < _w(&"weapon.kestrel_p9").base.damage, "small calibre")
	var lancet: WeaponStats = _w(&"weapon.lancet_45").base
	for id: StringName in [&"weapon.hornet_9", &"weapon.mastiff_45", &"weapon.wasp_pdw", &"weapon.ferret_9"]:
		assert_true(lancet.fire_rate_rpm >= _w(id).base.fire_rate_rpm, "Lancet out-fires %s" % id)
	assert_true(lancet.recoil_kick_deg < _w(&"weapon.mastiff_45").base.recoil_kick_deg, "low-recoil .45")
	var bastion: WeaponStats = _w(&"weapon.bastion_br").base
	assert_true(bastion.damage > _w(&"weapon.drover_762").base.damage and bastion.mag_size == 20, "battle rifle")
	assert_true(bastion.damage < _w(&"weapon.falchion_dmr").base.damage, "the DMR still hits harder")
	var lark: WeaponDef = _w(&"weapon.lark_carbine")
	assert_true(lark.fire_modes.has(&"burst3"), "carbine has a three-round burst")
	assert_true(lark.base.concealment > _w(&"weapon.corsair_ar").base.concealment, "carbine hides better")
	var tern: WeaponStats = _w(&"weapon.tern_556").base
	assert_true(tern.reload_time_s > _w(&"weapon.corsair_ar").base.reload_time_s, "bullpup reloads slower")


## Shotguns: the box-fed and drum-fed guns use the `shotgun_box` set (D-058; no pump) with shotgun sound;
## the double barrel reloads both shells at once (magazine-style, tactical = empty).
func test_shotgun_shapes() -> void:
	for id: StringName in [&"weapon.harrow_12", &"weapon.brute_12"]:
		var w: WeaponDef = _w(id)
		assert_eq(w.anim_set, &"shotgun_box", "%s: box/drum shotgun set (D-058)" % id)
		assert_eq(w.fire_cue, &"cue.weapon_shotgun_fire", "%s sounds like a shotgun" % id)
		assert_true(w.base.fire_rate_rpm > _w(&"weapon.plowman_12").base.fire_rate_rpm * 3.0, "%s fast follow-ups" % id)
		assert_eq(w.base.reload_per_round_s, 0.0, "%s detachable magazine" % id)
	assert_true(_w(&"weapon.brute_12").fire_modes.has(&"auto"), "drum gun is full auto")
	assert_eq(_w(&"weapon.harrow_12").fire_modes, [&"semi"] as Array[StringName], "box gun is semi-auto")
	var db: WeaponDef = _w(&"weapon.reaper_db")
	assert_eq(db.base.mag_size, 2, "two barrels")
	assert_near(db.base.reload_time_s, db.base.reload_empty_time_s, 0.0001, "both shells swapped every time")
	assert_true(db.base.damage > _w(&"weapon.plowman_12").base.damage, "double barrel hits hardest")
	assert_eq(db.fire_cue, &"cue.weapon_shotgun_fire", "12-gauge sound")


func test_lmg_and_sniper_shapes() -> void:
	var gale: WeaponStats = _w(&"weapon.gale_mg").base
	assert_true(gale.fire_rate_rpm > _w(&"weapon.rampart_lmg").base.fire_rate_rpm, "the fastest belt-fed")
	assert_true(gale.mag_size >= 100, "belt box")
	var osprey: WeaponDef = _w(&"weapon.osprey_762")
	assert_eq(osprey.fire_modes, [&"semi"] as Array[StringName], "semi-auto sniper")
	assert_eq(osprey.anim_set, &"rifle", "no bolt clip: the rifle set")
	assert_true(osprey.base.damage < _w(&"weapon.heron_308").base.damage, "less per shot than a bolt gun")
	var stock: WeaponStats = LoadoutResolver.resolve_weapon(osprey.id, [] as Array[StringName])
	assert_true(stock.magnification >= 4.0, "stock 4x scope")
	var shrike: WeaponDef = _w(&"weapon.shrike_44")
	var b: WeaponStats = shrike.base
	assert_true(b.reload_per_round_s > 0.0, "tube fed, one round at a time (D-045)")
	var s: WeaponStats = LoadoutResolver.resolve_weapon(shrike.id, [] as Array[StringName])
	assert_near(s.reload_time_s, b.reload_start_s + s.mag_size * b.reload_per_round_s + b.reload_end_s, 0.001, "tactical")
	assert_near(s.reload_empty_time_s, b.reload_start_s + s.mag_size * b.reload_per_round_s + b.reload_end_empty_s,
		0.001, "empty")


## Specials, expressed with existing WeaponStats fields only (mechanics questions for ENV A in the README).
func test_special_shapes() -> void:
	for id: StringName in [&"weapon.thorn_bow", &"weapon.vise_crossbow"]:
		var b: WeaponStats = _w(id).base
		assert_true(b.suppressed and b.noise_radius_m <= 1.0, "%s is silent" % id)
		assert_eq(b.mag_size, 1, "%s one projectile at a time" % id)
		assert_true(b.damage >= 300.0, "%s hits hard" % id)
	assert_true(_w(&"weapon.thorn_bow").base.concealment > _w(&"weapon.vise_crossbow").base.concealment, "bow hides better")
	var gl: WeaponStats = _w(&"weapon.thumper_40").base
	assert_true(gl.mag_size == 1 and gl.damage >= 800.0 and gl.total_ammo <= 10, "single-shot launcher, few rounds")
	var ft: WeaponStats = _w(&"weapon.furnace_ft").base
	assert_true(ft.falloff_end_m <= 12.0 and ft.falloff_min_mult == 0.0, "flame reaches about 10 m, then nothing")
	assert_true(ft.mag_size >= 300, "fuel tank")
	var saw: WeaponDef = _w(&"weapon.rotor_saw")
	assert_eq(saw.slot, Enums.WeaponSlot.SECONDARY, "the saw is a secondary (PD2 OVE9000)")
	assert_true(saw.base.falloff_end_m <= 2.5 and saw.base.falloff_min_mult == 0.0, "contact range only")
	var mg: WeaponStats = _w(&"weapon.cyclone_rotary").base
	assert_true(mg.fire_rate_rpm >= 1200.0 and mg.mag_size >= 500, "rotary: huge rate, huge box")
	assert_eq(mg.concealment, 0, "impossible to hide")
	for id: StringName in NEW_SETS.values():
		if _w(id).weapon_class == Enums.WeaponClass.SPECIAL:
			assert_false(_w(id).base.shield_pierce or _w(id).base.wall_pierce, "%s pierces nothing yet (L3.4)" % id)


## D-057: special-weapon mechanics live in WeaponDef.params (schemas from ENV A, game/systems/modifiers_params.md);
## mod params replace whole top-level blocks (shallow merge), so a nozzle carries a full `flame` block.
const PARAM_BLOCKS: Dictionary = {
	&"weapon.thorn_bow": ["charge", "projectile"], &"weapon.vise_crossbow": ["projectile"],
	&"weapon.thumper_40": ["projectile", "explosion"], &"weapon.furnace_ft": ["flame"],
	&"weapon.rotor_saw": ["saw"], &"weapon.cyclone_rotary": ["spin"],
}


func test_special_weapon_params() -> void:
	for id: StringName in PARAM_BLOCKS:
		var keys: Array = _w(id).params.keys()
		keys.sort()
		var want: Array = (PARAM_BLOCKS[id] as Array).duplicate()
		want.sort()
		assert_eq(keys, want, "%s params blocks" % id)
	var bow: WeaponDef = _w(&"weapon.thorn_bow")
	assert_eq(bow.fire_modes, [&"charge"] as Array[StringName], "hold to draw")
	assert_near(bow.base.armor_pierce, 1.0, 0.0001, "arrows pierce body armor")
	assert_near(_w(&"weapon.vise_crossbow").base.armor_pierce, 1.0, 0.0001, "bolts pierce body armor")
	assert_true(bool(bow.params["projectile"]["retrievable"]), "arrows can be picked up")
	assert_eq(_w(&"weapon.shrike_44").fire_modes, [&"lever"] as Array[StringName], "lever action")
	var flame_keys: Array = (_w(&"weapon.furnace_ft").params["flame"] as Dictionary).keys()
	flame_keys.sort()
	for m: StringName in [&"mod.furnace_wide_nozzle", &"mod.furnace_long_nozzle"]:
		var f: Dictionary = ContentDB.mod(m).params.get("flame", {})
		var k: Array = f.keys()
		k.sort()
		assert_eq(k, flame_keys, "%s carries a full flame block" % m)
	assert_true(float(ContentDB.mod(&"mod.furnace_long_nozzle").params["flame"]["range_m"]) > 10.0, "long reaches further")
	assert_true(float(ContentDB.mod(&"mod.furnace_wide_nozzle").params["flame"]["cone_deg"]) > 20.0, "wide cone")
