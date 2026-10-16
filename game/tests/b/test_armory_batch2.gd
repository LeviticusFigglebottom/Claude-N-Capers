## B4-12: armory batch 2 (ten weapons). Class shapes per pd2_fidelity L3.2/L3.4, the first-person clip
## constraints of ENV D's viewmodel sets (characters.md v1.4), the akimbo pair (D-050), the revolver's
## speedloader reload and the secondary pump gun's shell-by-shell reload (D-045).
extends TestCase

const BATCH2: Array[StringName] = [
	&"weapon.drover_762", &"weapon.mastiff_45", &"weapon.anvil_lmg", &"weapon.condor_50", &"weapon.mule_12",
	&"weapon.akimbo_warden_45", &"weapon.marshal_357", &"weapon.falchion_dmr", &"weapon.wasp_pdw",
	&"weapon.sparrow_mp",
]
const MAKERS: Array[String] = [
	"Halvard Arms", "Marrow & Kell", "Brannock Defense", "Tillman Ironworks", "Graff-Lindqvist",
]
## FP clip lengths (frames at 30 fps, SOURCE.txt of char_arms_fp): full-auto fire 3 f (restarted each
## shot, <= 1.5 shot intervals), shotgun fire with the pump 24 f, sniper fire 9 f + bolt 27 f.
const AUTO_FIRE_S: float = 3.0 / 30.0
const SHOTGUN_FIRE_S: float = 24.0 / 30.0
const SNIPER_CYCLE_S: float = 36.0 / 30.0


func before_all() -> void:
	ContentDB.clear_cache()


func _w(id: StringName) -> WeaponDef:
	return ContentDB.weapon(id)


func test_batch_exists_with_original_makers() -> void:
	for id: StringName in BATCH2:
		var w: WeaponDef = _w(id)
		assert_true(w != null, "%s exists" % id)
		if w == null:
			continue
		assert_has(MAKERS, w.manufacturer, "%s maker" % id)
		assert_true(w.display_name != "" and w.model != null, "%s name + model" % id)
	assert_true(ContentDB.all_weapons().size() >= 17, "P9 + B4-04 + B4-12")


## The new weapons must keep ENV D's shared viewmodel clips valid (test_arms checks the max rpm per set).
func test_fire_rates_fit_the_viewmodel_clips() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		var rpm: float = w.base.fire_rate_rpm
		match w.anim_set:
			&"smg", &"rifle", &"lmg":
				assert_true(AUTO_FIRE_S <= 1.5 * 60.0 / rpm + 0.0001, "%s %d rpm vs the 3 f fire clip" % [w.id, rpm])
			&"shotgun":
				assert_true(SHOTGUN_FIRE_S <= 60.0 / rpm, "%s %d rpm vs the pump clip" % [w.id, rpm])
			&"sniper":
				assert_true(SNIPER_CYCLE_S <= 60.0 / rpm + 0.002, "%s %d rpm vs fire + bolt" % [w.id, rpm])
				assert_true(w.fire_modes.has(&"bolt"), "%s sniper set = bolt action" % w.id)


## DMR: an AR-class semi-auto marksman rifle (no falloff, L3.2), hits much harder than the carbines.
func test_dmr_and_heavy_rifle_shapes() -> void:
	var dmr: WeaponStats = _w(&"weapon.falchion_dmr").base
	var heavy: WeaponStats = _w(&"weapon.drover_762").base
	var carbine: WeaponStats = _w(&"weapon.corsair_ar").base
	assert_eq(_w(&"weapon.falchion_dmr").fire_modes, [&"semi"] as Array[StringName], "DMR semi only")
	assert_eq(_w(&"weapon.falchion_dmr").anim_set, &"rifle", "DMR uses the rifle set")
	assert_true(dmr.damage > 2.5 * carbine.damage and dmr.mag_size <= 20, "DMR: few, heavy rounds")
	assert_true(heavy.damage > carbine.damage and heavy.fire_rate_rpm < carbine.fire_rate_rpm, "heavy AR")
	assert_true(heavy.concealment < carbine.concealment, "heavy AR hides worse")
	assert_true(dmr.concealment < heavy.concealment, "DMR hides worst of the ARs")


func test_smg_and_pistol_shapes() -> void:
	var pdw: WeaponStats = _w(&"weapon.wasp_pdw").base
	var heavy: WeaponStats = _w(&"weapon.mastiff_45").base
	var hornet: WeaponStats = _w(&"weapon.hornet_9").base
	assert_true(pdw.concealment > hornet.concealment and pdw.fire_rate_rpm > hornet.fire_rate_rpm, "PDW")
	assert_true(heavy.damage > hornet.damage and heavy.fire_rate_rpm < hornet.fire_rate_rpm, "heavy SMG")
	var mp: WeaponDef = _w(&"weapon.sparrow_mp")
	assert_true(mp.fire_modes.has(&"auto"), "machine pistol fires full auto")
	assert_true(mp.base.fire_rate_rpm > _w(&"weapon.kestrel_p9").base.fire_rate_rpm, "machine pistol rpm")
	var rev: WeaponStats = _w(&"weapon.marshal_357").base
	assert_eq(rev.mag_size, 6, "six-shot revolver")
	assert_true(rev.damage > _w(&"weapon.warden_45").base.damage * 2.0, "magnum hits hardest of the pistols")


## Second LMG and sniper keep their class shapes; the .50 out-hits the .308 and pierces (L3.4).
func test_lmg_and_sniper_shapes() -> void:
	var anvil: WeaponStats = _w(&"weapon.anvil_lmg").base
	var rampart: WeaponStats = _w(&"weapon.rampart_lmg").base
	assert_true(anvil.mag_size >= 100 and anvil.damage > rampart.damage, "heavy LMG")
	assert_true(anvil.concealment < 10, "LMG hides badly")
	var condor: WeaponStats = _w(&"weapon.condor_50").base
	var heron: WeaponStats = _w(&"weapon.heron_308").base
	assert_true(condor.damage > 2.0 * heron.damage and condor.fire_rate_rpm < heron.fire_rate_rpm, ".50 vs .308")
	assert_true(condor.armor_pierce >= 1.0 and condor.shield_pierce and condor.wall_pierce, ".50 pierces")
	assert_true(condor.falloff_min_mult > 1.0, ".50 gains damage with range")
	var stock: WeaponStats = LoadoutResolver.resolve_weapon(&"weapon.condor_50", [] as Array[StringName])
	assert_true(stock.magnification >= 6.0, "stock 6x scope")


## Secondary pump gun: shell-by-shell with the shared shotgun clip timings (D-044/D-045).
func test_mule_is_a_secondary_shell_loader() -> void:
	var w: WeaponDef = _w(&"weapon.mule_12")
	assert_eq(w.slot, Enums.WeaponSlot.SECONDARY, "secondary slot")
	assert_eq(w.fire_modes, [&"pump"] as Array[StringName], "pump")
	var b: WeaponStats = w.base
	assert_near(b.reload_start_s, 0.4, 0.0001, "start")
	assert_near(b.reload_per_round_s, 0.4333, 0.0001, "per shell")
	assert_near(b.reload_end_s, 0.4, 0.0001, "end")
	assert_near(b.reload_end_empty_s, 1.2, 0.0001, "end empty")
	var s: WeaponStats = LoadoutResolver.resolve_weapon(w.id, [] as Array[StringName])
	assert_near(s.reload_time_s, 0.4 + 5 * 0.4333 + 0.4, 0.001, "derived tactical")
	assert_near(s.reload_empty_time_s, 0.4 + 5 * 0.4333 + 1.2, 0.001, "derived empty")
	assert_true(b.concealment > _w(&"weapon.plowman_12").base.concealment, "hides better than the Plowman")


## Revolver: speedloader = magazine-style reload (PD2), so no per-round fields; tactical = empty.
func test_revolver_speedloader_reload() -> void:
	var b: WeaponStats = _w(&"weapon.marshal_357").base
	assert_eq(b.reload_per_round_s, 0.0, "no shell-by-shell")
	assert_near(b.reload_time_s, b.reload_empty_time_s, 0.0001, "the speedloader always swaps all six")
	assert_eq(_w(&"weapon.marshal_357").anim_set, &"revolver", "revolver viewmodel set")
	assert_false(_w(&"weapon.marshal_357").mod_slots.has(Enums.ModType.SUPPRESSOR), "no revolver suppressor (PD2)")


## D-050 akimbo pair: one WeaponDef, PISTOL class, primary slot, anim_set `akimbo`, pistol cue family,
## double the Warden's magazine; `akimbo = true` (D-050), only on the pair.
func test_akimbo_pair() -> void:
	var w: WeaponDef = _w(&"weapon.akimbo_warden_45")
	var one: WeaponDef = _w(&"weapon.warden_45")
	assert_eq(w.weapon_class, Enums.WeaponClass.PISTOL, "pistol class")
	assert_eq(w.slot, Enums.WeaponSlot.PRIMARY, "primary slot (PD2)")
	assert_eq(w.anim_set, &"akimbo", "akimbo viewmodel set")
	assert_true(w.akimbo, "WeaponDef.akimbo set (D-050)")
	assert_false(one.akimbo, "the single Warden is not akimbo")
	assert_eq(w.fire_cue, one.fire_cue, "pistol fire cue")
	assert_eq(w.base.mag_size, 2 * one.base.mag_size, "two magazines")
	assert_true(w.base.total_ammo > one.base.total_ammo, "more reserve")
	assert_true(w.base.spread_deg_ads > one.base.spread_deg_ads, "two guns aim worse")
	assert_true(w.base.concealment < one.base.concealment, "two guns hide worse")
	# every pair mod shows on both guns: it reuses the single gun's glb
	for slot: Variant in w.mod_slots:
		for mid: Variant in w.mod_slots[slot]:
			var m: WeaponModDef = ContentDB.mod(StringName(mid))
			# D-118: the shared rail gadgets (mod_rail_*) fit the Warden's dust-cover rail like its own parts
			var part: bool = m.model != null and (m.model.resource_path.contains("/mod_w45_")
					or m.model.resource_path.contains("/mod_rail_"))
			assert_true(part, "%s uses a Warden part" % mid)
