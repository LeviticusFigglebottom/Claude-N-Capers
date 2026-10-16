## Headless weapon balance audit (D-115). Owner: ENV B. Tool only, never loaded by the game; changes no data.
## Library of weapon_balance_cli.gd (loaded at run time: a -s main script compiles before the autoloads exist).
## For every WeaponDef, the STOCK build (LoadoutResolver.resolve_weapon(id, []) = base + default_mods, then AmmoStats.apply)
## and its StatCalculator.display numbers, plus derived numbers against ENV A's EnemyDefs (read-only):
## * sustained DPS: per-shot damage x mag / ((mag - 1) x 60/rpm + max(60/rpm, empty reload));
## * TTK (shots and seconds from a full mag, point blank, every shot/pellet hits, no skills/crits) on the TAC Heavy
##   (head = x headshot_mult[diff] x weapon bonus; body = from the FLANK/REAR (outside the frontal arc): from the front a
##   non-AP bullet body hit deals x frontal_armor (0); with AP chance p the front body expectation is p x damage) and on the
##   Wrecker (head route: faceplate then visor take x1 per bullet/pellet, excess lost, then the head x headshot_mult; body
##   route: x1, explosions x explosive_mult; flame / saw / blasts always hit BODY, explosions never hit plates);
## * ammo economy: total ammo / shots-to-kill (TAC Heavy, head) and pickup average / shots-to-kill.
## Damage rules: docs/contracts/damage.md v1.3, NpcHitRules.pre_zone, WreckerArmor.take_hit, SpecialWeapons.
extends RefCounted

const CLASS_NAMES: Array[String] = ["pistol", "smg", "ar", "shotgun", "lmg", "sniper", "special"]
## ENV A's EnemyDefs are reached through B's range dummy table (data, D-010), never by a hard path.
const DUMMIES_PATH: String = "res://content/data/range/range_dummies.tres"
const HEAVY_DUMMY: StringName = &"range_dummy.heavy"
const WRECKER_DUMMY: StringName = &"range_dummy.wrecker"
const INF_SHOTS: int = 99999
const RANGE_M: float = 20.0


## The EnemyDef a range dummy row mirrors.
static func enemy(dummy_id: StringName) -> EnemyDef:
	var table: RangeDummyTable = load(DUMMIES_PATH) as RangeDummyTable
	var row: RangeDummyDef = table.dummy(dummy_id) if table != null else null
	return row.enemy_def() if row != null else null


## Markdown audit for `diff`; also written to `out_path` when given.
static func run(diff: int, out_path: String = "") -> String:
	var md: String = render(collect(diff), diff)
	if out_path != "":
		var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(md)
	return md


## One row per weapon (sorted by class, slot, unlock level).
static func collect(diff: int) -> Array[Dictionary]:
	var heavy: EnemyDef = enemy(HEAVY_DUMMY)
	var wrecker: EnemyDef = enemy(WRECKER_DUMMY)
	var rows: Array[Dictionary] = []
	for res: Variant in ContentDB.all_weapons():
		var def: WeaponDef = res as WeaponDef
		if def == null or def.weapon_class > Enums.WeaponClass.SPECIAL:
			continue
		rows.append(row_for(def, heavy, wrecker, diff))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["cls"] != b["cls"]:
			return int(a["cls"]) < int(b["cls"])
		if a["slot"] != b["slot"]:
			return int(a["slot"]) < int(b["slot"])
		return int(a["unlock"]) < int(b["unlock"]))
	return rows


static func row_for(def: WeaponDef, heavy: EnemyDef, wrecker: EnemyDef, diff: int) -> Dictionary:
	var none: Array[StringName] = []
	var mods: Array[StringName] = []
	for m: WeaponModDef in LoadoutResolver.applied_mods(def, none):
		mods.append(m.id)
	var s: WeaponStats = AmmoStats.apply(LoadoutResolver.resolve_weapon(def.id, none), def, mods)
	var disp: Dictionary = StatCalculator.display(s)
	var p: Dictionary = SpecialWeapons.params_of(def, mods)
	var kind: StringName = &"hitscan"
	if p.has("flame"):
		kind = &"flame"
	elif p.has("saw"):
		kind = &"saw"
	elif p.has("explosion"):
		kind = &"explosive"
	elif p.has("projectile"):
		kind = &"projectile"
	var pellets: int = maxi(s.pellets, 1)
	var interval: float = 60.0 / maxf(s.fire_rate_rpm, 1.0)
	var reload: Vector2 = LoadoutResolver.reload_times(s)
	var cycle: float = float(s.mag_size - 1) * interval + maxf(interval, reload.y)
	var shot_dmg: float = s.damage * float(pellets)
	var r: Dictionary = {
		"id": String(def.id).trim_prefix("weapon."), "name": def.display_name, "cls": int(def.weapon_class),
		"slot": "P" if def.slot == Enums.WeaponSlot.PRIMARY else "S", "unlock": def.unlock_level, "price": def.price,
		"kind": kind, "dmg": shot_dmg, "pellet": s.damage, "pellets": pellets, "rpm": s.fire_rate_rpm,
		"mag": s.mag_size, "ammo": s.total_ammo, "acc": int(disp["accuracy"]), "stab": int(disp["stability"]),
		"conc": s.concealment, "threat": int(disp["threat"]), "rl": reload.x, "rle": reload.y,
		"pk_min": s.ammo_pickup_min, "pk_max": s.ammo_pickup_max, "ap": s.armor_pierce, "sp": s.shield_pierce,
		"hs_bonus": s.headshot_mult, "f_start": s.falloff_start_m, "f_end": s.falloff_end_m, "f_min": s.falloff_min_mult,
		"dmg_far": shot_dmg * CombatSystem.falloff_mult(s, RANGE_M),
	}
	r["dps"] = shot_dmg * float(s.mag_size) / cycle
	var burn: float = 0.0
	if kind == &"flame":
		burn = float((p["flame"] as Dictionary).get("dot_damage_per_s", 0.0))
		r["dps"] = float(r["dps"]) + burn  # the burn refreshes while the stream stays on the target
	var expl: float = 1.0 if kind != &"explosive" else float(NpcHitRules.armor_of(wrecker)["explosive_mult"])
	var body_only: bool = kind == &"flame" or kind == &"saw" or kind == &"explosive"
	# TAC Heavy (L4.2): head x zone mult; body from the flank (frontal plate blocks non-AP front hits).
	var hp_h: float = heavy.health[clampi(diff, 0, heavy.health.size() - 1)]
	var hz_h: float = heavy.headshot_mult[clampi(diff, 0, heavy.headshot_mult.size() - 1)]
	var front: float = NpcHitRules.armor_of(heavy)["frontal_armor"]
	var ap: float = 1.0 if kind != &"hitscan" and kind != &"projectile" else clampf(s.armor_pierce, 0.0, 1.0)
	r["h_body"] = shots_flat(hp_h, shot_dmg)
	r["h_front"] = shots_flat(hp_h, shot_dmg * (ap + (1.0 - ap) * front))
	r["h_head"] = r["h_body"] if body_only else shots_flat(hp_h, shot_dmg * hz_h * s.headshot_mult)
	# Wrecker (L4.6).
	var hp_w: float = wrecker.health[clampi(diff, 0, wrecker.health.size() - 1)]
	var hz_w: float = wrecker.headshot_mult[clampi(diff, 0, wrecker.headshot_mult.size() - 1)]
	var plates: Array[float] = NpcHitRules.armor_of(wrecker)["plate_health"]
	r["w_body"] = shots_flat(hp_w, shot_dmg * expl)
	r["w_head"] = r["w_body"] if body_only else shots_wrecker_head(hp_w, plates, s.damage, pellets, hz_w * s.headshot_mult)
	for k: String in ["h_body", "h_front", "h_head", "w_body", "w_head"]:
		r[k + "_s"] = ttk_seconds(int(r[k]), s.mag_size, interval, cycle)
	var best_h: int = mini(int(r["h_head"]), int(r["h_body"]))
	r["econ_total"] = float(s.total_ammo) / float(maxi(int(r["h_head"]), 1))
	r["econ_pick"] = 0.5 * (s.ammo_pickup_min + s.ammo_pickup_max) / float(maxi(int(r["h_head"]), 1))
	r["best_h"] = best_h
	return r


## Shots to deal `hp` at `per_shot` each (INF_SHOTS when the hit deals nothing).
static func shots_flat(hp: float, per_shot: float) -> int:
	if per_shot <= 0.0001:
		return INF_SHOTS
	return int(ceil(hp / per_shot - 0.0001))


## Shots at the Wrecker's head: every pellet hits the current plate (x1, excess per pellet lost; the next pellet hits
## the next stage, WreckerArmor.take_hit), then the head at x `head_mult`.
static func shots_wrecker_head(hp: float, plates: Array[float], pellet_dmg: float, pellets: int, head_mult: float) -> int:
	if pellet_dmg <= 0.0:
		return INF_SHOTS
	var plate_hp: Array[float] = plates.duplicate()
	var stage: int = 0
	var left: float = hp
	var shots: int = 0
	while left > 0.0 and shots < INF_SHOTS:
		shots += 1
		for i: int in range(pellets):
			if stage < plate_hp.size():
				plate_hp[stage] -= minf(pellet_dmg, plate_hp[stage])
				if plate_hp[stage] <= 0.0:
					stage += 1
			else:
				left -= pellet_dmg * head_mult
	return shots


## Seconds from the first shot to the `n`-th (full mag at start, empty reloads between mags).
static func ttk_seconds(n: int, mag: int, interval: float, cycle: float) -> float:
	if n >= INF_SHOTS:
		return INF
	var k: int = n - 1
	return float(k / maxi(mag, 1)) * cycle + float(k % maxi(mag, 1)) * interval


static func fmt_shots(n: int, sec: float, ammo: int) -> String:
	if n >= INF_SHOTS:
		return "blocked"
	var tail: String = "!" if n > ammo else ""
	return "%d/%.2fs%s" % [n, sec, tail]


static func render(rows: Array[Dictionary], diff: int) -> String:
	var heavy: EnemyDef = enemy(HEAVY_DUMMY)
	var wrecker: EnemyDef = enemy(WRECKER_DUMMY)
	var lines: PackedStringArray = []
	lines.append("<!-- generated by res://content/progression/tools/weapon_balance.gd (difficulty %d) -->" % diff)
	lines.append("Targets: TAC Heavy %.0f HP (head x%.1f, frontal plate x%.1f in %.0f deg); Wrecker %.0f HP (head x%.1f, plates %s)."
		% [heavy.health[diff], heavy.headshot_mult[diff], float(NpcHitRules.armor_of(heavy)["frontal_armor"]),
		float(NpcHitRules.armor_of(heavy)["frontal_armor_arc_deg"]), wrecker.health[diff], wrecker.headshot_mult[diff],
		str(NpcHitRules.armor_of(wrecker)["plate_health"])])
	for c: int in range(CLASS_NAMES.size()):
		lines.append("")
		lines.append("### %s" % CLASS_NAMES[c])
		lines.append("")
		lines.append("| weapon | slot | lvl | dmg (pellet) | dmg@20m | rpm | mag/total | acc | stab | conc | reload t/e | pickup"
			+ " | AP(+S shield) | DPS | Heavy head | Heavy flank body | Heavy front body | Wrecker head | Wrecker body"
			+ " | ammo/kill | pickup/kill |")
		lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
		for r: Dictionary in rows:
			if int(r["cls"]) != c:
				continue
			var dmg: String = "%.0f" % float(r["dmg"])
			if int(r["pellets"]) > 1:
				dmg += " (%.0fx%d)" % [float(r["pellet"]), int(r["pellets"])]
			var ammo: int = int(r["ammo"])
			var fmt: String = "| %s | %s | %d | %s | %.0f | %.0f | %d/%d | %d | %d | %d | %.2f/%.2f | %.1f-%.1f | %s | %.0f"
			fmt += " | %s | %s | %s | %s | %s | %.1f | %.2f |"
			lines.append(fmt % [
				r["id"], r["slot"], int(r["unlock"]), dmg, float(r["dmg_far"]), float(r["rpm"]), int(r["mag"]), ammo,
				int(r["acc"]), int(r["stab"]), int(r["conc"]), float(r["rl"]), float(r["rle"]), float(r["pk_min"]),
				float(r["pk_max"]), "%.2f%s" % [float(r["ap"]), "+S" if bool(r["sp"]) else ""], float(r["dps"]),
				fmt_shots(int(r["h_head"]), float(r["h_head_s"]), ammo), fmt_shots(int(r["h_body"]), float(r["h_body_s"]), ammo),
				fmt_shots(int(r["h_front"]), float(r["h_front_s"]), ammo), fmt_shots(int(r["w_head"]), float(r["w_head_s"]), ammo),
				fmt_shots(int(r["w_body"]), float(r["w_body_s"]), ammo), float(r["econ_total"]), float(r["econ_pick"])])
	lines.append("")
	lines.append("### flags")
	lines.append("")
	for f: String in flags(rows):
		lines.append("- " + f)
	return "\n".join(lines) + "\n"


## Mechanical outlier checks (the report adds the PD2-shape judgement). Columns compared: higher is better, reload lower.
static func flags(rows: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = []
	for a: Dictionary in rows:
		var peers: Array[Dictionary] = []
		for b: Dictionary in rows:
			if b["id"] != a["id"] and b["cls"] == a["cls"] and b["slot"] == a["slot"]:
				peers.append(b)
		var leads: bool = peers.size() >= 2
		for b: Dictionary in peers:
			if not wins(b, a).is_empty():
				leads = false
			var a_wins: PackedStringArray = wins(a, b)
			if wins(b, a).is_empty() or a_wins.size() > 1 or int(b["unlock"]) > int(a["unlock"]):
				continue
			if a_wins.is_empty():
				out.append("DOMINATED: %s (lvl %d) is never better than %s (lvl %d)" % [a["id"], a["unlock"], b["id"], b["unlock"]])
			else:
				out.append("NEAR-DOMINATED: %s (lvl %d) beats %s (lvl %d) only in %s" % [a["id"], a["unlock"], b["id"], b["unlock"], a_wins[0]])
		if leads:
			out.append("LEADS: %s leads its class/slot in every column" % a["id"])
	out.append_array(class_flags(rows))
	return out


## Columns where `a` is strictly better than `b`.
static func wins(a: Dictionary, b: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for k: String in ["dmg", "rpm", "mag", "ammo", "acc", "stab", "conc", "dps", "pk_max", "dmg_far"]:
		if float(a[k]) > float(b[k]) + 0.0001:
			out.append(k)
	for k: String in ["rl", "rle", "h_head"]:
		if float(a[k]) < float(b[k]) - 0.0001:
			out.append(k)
	return out


## Cross-class PD2-shape checks.
static func class_flags(rows: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = []
	var ar_min_dps: float = INF
	var ar_max_dmg: float = 0.0
	var lmg_best: float = 0.0
	var core_best_econ: float = 0.0
	var core_best_id: String = ""
	for r: Dictionary in rows:
		var c: int = int(r["cls"])
		if c == Enums.WeaponClass.ASSAULT_RIFLE:
			ar_min_dps = minf(ar_min_dps, float(r["dps"]))
			ar_max_dmg = maxf(ar_max_dmg, float(r["dmg"]))
		if c == Enums.WeaponClass.LMG:
			lmg_best = maxf(lmg_best, float(r["econ_total"]))
		elif c != Enums.WeaponClass.SPECIAL and float(r["econ_total"]) > core_best_econ:
			core_best_econ = float(r["econ_total"])
			core_best_id = String(r["id"])
	for r: Dictionary in rows:
		var c: int = int(r["cls"])
		if (c == Enums.WeaponClass.PISTOL or c == Enums.WeaponClass.SMG) and float(r["dps"]) > ar_min_dps:
			out.append("SECONDARY-DPS: %s (%s) sustained DPS %.0f > the weakest AR (%.0f)" % [r["id"], CLASS_NAMES[c], r["dps"], ar_min_dps])
		if c == Enums.WeaponClass.SNIPER and float(r["dmg"]) <= ar_max_dmg + 15.0:
			out.append("SNIPER-PER-SHOT: %s %.0f per shot vs the AR maximum %.0f" % [r["id"], r["dmg"], ar_max_dmg])
		if c == Enums.WeaponClass.SHOTGUN and float(r["dmg_far"]) > 0.5 * float(r["dmg"]):
			out.append("SHOTGUN-RANGE: %s keeps %.0f%% of its damage at %.0f m" % [r["id"], 100.0 * float(r["dmg_far"]) / float(r["dmg"]), RANGE_M])
		if c == Enums.WeaponClass.SPECIAL and int(r["w_head"]) <= int(r["ammo"]) and float(r["w_head_s"]) < 15.0:
			out.append("WRECKER: %s kills a Wrecker in %.1f s (%d of %d rounds)" % [r["id"], r["w_head_s"], r["w_head"], r["ammo"]])
		if int(r["h_head"]) > int(r["ammo"]):
			out.append("AMMO: %s cannot kill one TAC Heavy with its whole reserve" % r["id"])
		if float(r["pk_min"]) < 1.0 and float(r["pk_max"]) > 0.0:
			out.append("PICKUP-FLOOR: %s pickup min %.1f < 1 (AmmoPickupSystem floors every box at 1 round)" % [r["id"], r["pk_min"]])
	if core_best_econ > lmg_best:
		out.append("LMG-ECON: %s ammo/kill %.1f beats the best LMG (%.1f)" % [core_best_id, core_best_econ, lmg_best])
	return out
