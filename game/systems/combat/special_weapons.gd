## Special weapons (B4-18, D-055): bows/crossbows, launchers, flamethrower, saw, minigun. Owner: ENV A.
## Fidelity: L3.4 (fire ignores armor and shields), L3.6 (explosive falloff), L4.5 (Bulwark), P5 (armory).
##
## Per-weapon data lives in `WeaponDef.params` (shallow-merged with each applied mod's
## `WeaponModDef.params`, in mod order; D-057, schema in game/systems/modifiers_params.md):
##   charge     = {draw_time_s, min_damage_mult, min_speed_mult}            fire mode &"charge" (bow)
##   projectile = {speed_mps, gravity_mult, lifetime_s, retrievable, pickup_radius_m, despawn_s}
##   explosion  = {radius_m, arm_distance_m}                                 impact -> Explosion.apply
##   flame      = {range_m, cone_deg, dot_damage_per_s, dot_duration_s, panic_chance, panic_s}
##   saw        = {range_m, cone_deg, wear_per_tick_npc, wear_per_tick_object, cut_rate_mult}
##   spin       = {spin_up_s, spin_down_s, move_speed_mult}                  minigun
## Kinds: a weapon with `flame` is a cone volume (DamageType.FIRE + BurnStatus), `saw` a short volume
## that only fires while touching something, `projectile` a WeaponProjectile, anything else hitscan.
## Cues (audio_cues.md v1.1, per anim_set): `cue(..)` emits one-shot foley (draw, ignite/stop, rev, spin
## up/down) where the shooter is simulated and replicates it from the authority; impacts/explosions
## of projectiles come from the server (`impact_cue` in the projectile params).
## The server re-derives flame/saw targets from the validated claim origin + direction (it ignores
## claimed hits for them) and spawns projectiles itself; clients only predict ammo and presentation.
class_name SpecialWeapons
extends RefCounted

## Melee body axis (cone_targets body_axis): shins to crown above the target's feet, sampled this often.
const AXIS_LOW_M: float = 0.3
const AXIS_HIGH_M: float = 1.7
const AXIS_SAMPLES: int = 14
const KIND_HITSCAN: StringName = &""
const KIND_PROJECTILE: StringName = &"projectile"
const KIND_FLAME: StringName = &"flame"
const KIND_SAW: StringName = &"saw"
## Prefabs a saw can open (gameplay_prefabs v1.3, D-057): `saw_cut(seconds: float, attacker_net_id: int)`.
const SAW_GROUP: StringName = G.SAW_TARGET
const SAW_DAMAGE_KEY: StringName = &"weapon.saw_damage_mult"
const SAW_WEAR_KEY: StringName = &"weapon.saw_wear_mult"
const SAW_SHIELD_KEY: StringName = &"weapon.saw_shield_pierce"
const DEFAULT_SAW_CONE_DEG: float = 40.0

## anim_sets whose impacts reuse another set's cue (crossbow bolts thunk like arrows, audio_cues.md).
const IMPACT_CUE_SET: Dictionary = {&"crossbow": &"bow"}

static var _cache: Dictionary = {}


## [R] Weapon foley `cue.weapon_<anim_set>_<suffix>` at `pos` (local, replicated from the authority).
static func cue(def: WeaponDef, suffix: String, pos: Vector3, source_net_id: int) -> void:
	if def == null:
		return
	var id: StringName = StringName("cue.weapon_%s_%s" % [def.anim_set, suffix])
	EventBus.audio_cue_requested.emit(id, pos, source_net_id)
	if Net.is_authority():
		Net.replicate_event(&"audio_cue_requested", [id, pos, source_net_id])


## Merged special params of weapon `def` with mods `mod_ids` (cached per weapon + mod list).
static func params_of(def: WeaponDef, mod_ids: Array[StringName] = []) -> Dictionary:
	if def == null:
		return {}
	var key: String = "%s|%s" % [def.id, ",".join(PackedStringArray(mod_ids))]
	if _cache.has(key) and _cache[key][0] == def:
		return _cache[key][1] as Dictionary
	var out: Dictionary = def.params.duplicate(true)
	for m: WeaponModDef in LoadoutResolver.applied_mods(def, mod_ids):
		out.merge(m.params.duplicate(true), true)
	_cache[key] = [def, out]
	return out


## Special params of `crew`'s weapon in slot `ws` ({} for plain guns).
static func params_for(crew: CrewController, ws: int) -> Dictionary:
	if crew == null or crew.weapons == null or not crew.weapons.has_weapon(ws):
		return {}
	var mods: Array[StringName] = []
	var l: Loadout = crew.loadout
	if l != null:
		mods = l.primary_mods if ws == Enums.WeaponSlot.PRIMARY else l.secondary_mods
	return params_of(ContentDB.weapon(crew.weapons.weapon_id(ws)), mods)


static func kind_of(p: Dictionary) -> StringName:
	if p.has("flame"):
		return KIND_FLAME
	if p.has("saw"):
		return KIND_SAW
	if p.has("projectile"):
		return KIND_PROJECTILE
	return KIND_HITSCAN


static func block(p: Dictionary, name: String) -> Dictionary:
	var v: Variant = p.get(name, {})
	return v as Dictionary if v is Dictionary else {}


## Bow draw (0..1) scaling of `min_key` (min_damage_mult / min_speed_mult): min at 0, x1 at full draw.
static func charge_mult(p: Dictionary, charge: float, min_key: String) -> float:
	var c: Dictionary = block(p, "charge")
	if c.is_empty():
		return 1.0
	return lerpf(float(c.get(min_key, 1.0)), 1.0, clampf(charge, 0.0, 1.0))


static func draw_time(p: Dictionary) -> float:
	return maxf(float(block(p, "charge").get("draw_time_s", 0.0)), 0.0)


## Damageable targets (not crew: no friendly fire) whose centre lies within `range_m` of `origin` and
## inside the cone of full angle `cone_deg` around `fwd`, with blast line of sight (shields don't block).
## `body_axis` (melee, P GN-P1): test the point of the target's body axis (AXIS_LOW_M..AXIS_HIGH_M above its feet)
## nearest the aim line instead of its centre, so a close or level swing at a standing body reaches it (PD2: the
## blade hits whatever of the body lies along the reach, not only the chest).
static func cone_targets(crew: CrewController, origin: Vector3, fwd: Vector3, range_m: float, cone_deg: float,
		body_axis: bool = false) -> Array[Object]:
	var out: Array[Object] = []
	if crew == null or not crew.is_inside_tree() or range_m <= 0.0:
		return out
	var tw: CombatTweak = CombatTweak.data()
	var cos_half: float = cos(deg_to_rad(clampf(cone_deg, 0.0, 179.0) * 0.5))
	for t: Object in Explosion.targets_in_sphere(crew, origin, range_m, tw):
		if t is CrewController:
			continue
		var c: Vector3 = _axis_point(t, origin, fwd) if body_axis else _center(t, origin)
		if _in_cone(origin, fwd, c, range_m, cos_half) and Explosion.blast_los(crew, origin, c, t, tw):
			out.append(t)
	return out


## Saw-openable prefabs (group SAW_GROUP) in front of `origin`.
static func saw_objects(crew: CrewController, origin: Vector3, fwd: Vector3, range_m: float, cone_deg: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if crew == null or not crew.is_inside_tree():
		return out
	var cos_half: float = cos(deg_to_rad(clampf(cone_deg, 0.0, 179.0) * 0.5))
	for n: Node in crew.get_tree().get_nodes_in_group(SAW_GROUP):
		var n3: Node3D = n as Node3D
		if n3 == null or not n3.has_method(&"saw_cut"):
			continue
		var p: Vector3 = saw_point_of(n3)
		if _in_cone(origin, fwd, p, range_m, cos_half) and _reaches(crew, origin, p, n3):
			out.append(n3)
	return out


## Where a saw target is cut: its `saw_point()` (e.g. a safe's lock) when it has one, else its origin.
static func saw_point_of(n: Node3D) -> Vector3:
	if n.has_method(&"saw_point"):
		return n.call(&"saw_point") as Vector3
	return n.global_position


## Nothing but `target` itself (any of its collision bodies) lies between `origin` and `point`.
static func _reaches(crew: CrewController, origin: Vector3, point: Vector3, target: Node) -> bool:
	var tw: CombatTweak = CombatTweak.data()
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, point, tw.los_mask)
	q.exclude = [crew.get_rid()]
	var hit: Dictionary = crew.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	var col: Node = hit.get("collider") as Node
	return col != null and (col == target or target.is_ancestor_of(col))


## Client/server: would a saw cut something right now (cutting air costs no blade wear)?
static func saw_has_contact(crew: CrewController, origin: Vector3, fwd: Vector3, p: Dictionary) -> bool:
	var s: Dictionary = block(p, "saw")
	var r: float = float(s.get("range_m", 1.6))
	var cone: float = float(s.get("cone_deg", DEFAULT_SAW_CONE_DEG))
	return not cone_targets(crew, origin, fwd, r, cone).is_empty() or not saw_objects(crew, origin, fwd, r, cone).is_empty()


## Server, after CrewWeapons.server_commit_shot: apply a special shot. Returns the DamageInfo results.
static func server_apply(shooter: CrewController, ws: int, claim: Dictionary, p: Dictionary) -> Array[Dictionary]:
	var origin: Vector3 = claim.get("origin", shooter.eye_position())
	var dir: Vector3 = (claim.get("direction", shooter.aim_direction()) as Vector3).normalized()
	match kind_of(p):
		KIND_FLAME:
			return _apply_flame(shooter, ws, origin, dir, claim, p)
		KIND_SAW:
			return _apply_saw(shooter, ws, origin, dir, claim, p)
		KIND_PROJECTILE:
			spawn_projectile(shooter, ws, claim, p)
	return [] as Array[Dictionary]


static func _apply_flame(shooter: CrewController, ws: int, origin: Vector3, dir: Vector3, claim: Dictionary,
		p: Dictionary) -> Array[Dictionary]:
	var f: Dictionary = block(p, "flame")
	var out: Array[Dictionary] = []
	var wid: StringName = StringName(claim.get("weapon_id", &""))
	for t: Object in cone_targets(shooter, origin, dir, float(f.get("range_m", 10.0)), float(f.get("cone_deg", 20.0))):
		var c: Vector3 = _center(t, origin)
		var info: Dictionary = Damage.info(shooter.weapons.damage_at(ws, 0.0), Enums.DamageType.FIRE,
			Enums.HitZone.BODY, wid, c, (c - origin).normalized(), shooter.net_id)
		info["pierced_armor"] = true  # L3.4: fire ignores armor (shields: CombatTweak.shield_fire_damage_mult)
		var res: Dictionary = CombatSystem.deliver_hit(t, info, shooter.net_id)
		out.append(res)
		var npc: NpcBase = t as NpcBase
		if npc != null and npc.alive:
			BurnStatus.ignite(npc, shooter.net_id, wid, f)
	return out


static func _apply_saw(shooter: CrewController, ws: int, origin: Vector3, dir: Vector3, claim: Dictionary,
		p: Dictionary) -> Array[Dictionary]:
	var s: Dictionary = block(p, "saw")
	var r: float = float(s.get("range_m", 1.6))
	var cone: float = float(s.get("cone_deg", DEFAULT_SAW_CONE_DEG))
	var w: CrewWeapons = shooter.weapons
	var wid: StringName = StringName(claim.get("weapon_id", &""))
	var q: StringName = Enums.weapon_class_qualifier(Enums.WeaponClass.SPECIAL)
	var targets: Array[Object] = cone_targets(shooter, origin, dir, r, cone)
	var objects: Array[Node3D] = saw_objects(shooter, origin, dir, r, cone)
	var out: Array[Dictionary] = []
	if targets.is_empty() and objects.is_empty():
		w.set_ammo(ws, w.mag(ws) + 1, w.reserve(ws))  # cutting air: no blade wear (refund the round)
		return out
	var dmg: float = w.damage_at(ws, 0.0) * Modifiers.mult(shooter.slot, SAW_DAMAGE_KEY, q)
	var pierce_shield: bool = bool(s.get("shield_pierce", true)) or Modifiers.flag(shooter.slot, SAW_SHIELD_KEY, q)
	for t: Object in targets:
		var c: Vector3 = _center(t, origin)
		var info: Dictionary = Damage.info(dmg, Enums.DamageType.BULLET, Enums.HitZone.BODY, wid, c,
			(c - origin).normalized(), shooter.net_id)
		info["pierced_armor"] = true
		info["shield_pierce"] = pierce_shield
		out.append(CombatSystem.deliver_hit(t, info, shooter.net_id))
	var interval: float = 60.0 / maxf(w.stats(ws).fire_rate_rpm, 1.0)
	for o: Node3D in objects:
		o.call(&"saw_cut", interval * float(s.get("cut_rate_mult", 1.0)), shooter.net_id)
	var wear_key: String = "wear_per_tick_npc" if not targets.is_empty() else "wear_per_tick_object"
	var wear: float = maxf(float(s.get(wear_key, 1.0)), 0.0) * Modifiers.mult(shooter.slot, SAW_WEAR_KEY, q)
	_apply_wear(w, ws, wear)
	return out


## Blade wear of one cutting tick (one round already consumed): whole extra rounds, fraction rolled.
static func _apply_wear(w: CrewWeapons, ws: int, wear: float) -> void:
	var whole: int = int(floor(wear))
	var frac: float = wear - float(whole)
	var extra: int = whole - 1
	if frac > 0.0 and GameRng.stream(&"saw_wear").randf() < frac:
		extra += 1
	if extra != 0:
		w.set_ammo(ws, clampi(w.mag(ws) - extra, 0, w.mag_size(ws)), w.reserve(ws))


## Server: launch the projectile of an accepted shot (arrow, bolt, grenade) under HeistRuntime.dynamic_root.
static func spawn_projectile(shooter: CrewController, ws: int, claim: Dictionary, p: Dictionary) -> WeaponProjectile:
	var rt: HeistRuntime = HeistRuntime.of(shooter)
	var parent: Node = rt.dynamic_root if rt != null and rt.dynamic_root != null else shooter.get_parent()
	if parent == null:
		return null
	var pr: Dictionary = block(p, "projectile")
	var ex: Dictionary = block(p, "explosion")
	var charge: float = float(claim.get("charge", 1.0))
	var dir: Vector3 = (claim.get("direction", shooter.aim_direction()) as Vector3).normalized()
	var origin: Vector3 = claim.get("origin", shooter.eye_position())
	var prof: Dictionary = CombatSystem.pierce_profile(shooter, ws)
	var def: WeaponDef = ContentDB.weapon(StringName(claim.get("weapon_id", &"")))
	var cue_set: StringName = def.anim_set if def != null else &""
	var impact_cue: String = ""
	if cue_set != &"":
		impact_cue = "cue.weapon_%s_%s" % [IMPACT_CUE_SET.get(cue_set, cue_set), "explode" if not ex.is_empty() else "impact"]
	var proj: WeaponProjectile = WeaponProjectile.new()
	proj.name = "Projectile_%d_%d" % [shooter.slot, int(claim.get("seq", 0))]
	proj.params = {
		"velocity": dir * float(pr.get("speed_mps", 60.0)) * charge_mult(p, charge, "min_speed_mult"),
		"gravity_mult": float(pr.get("gravity_mult", 1.0)), "lifetime_s": float(pr.get("lifetime_s", 10.0)),
		"damage": shooter.weapons.damage_at(ws, 0.0) * charge_mult(p, charge, "min_damage_mult"),
		"headshot_bonus": shooter.weapons.headshot_bonus(ws), "weapon_id": StringName(claim.get("weapon_id", &"")),
		"weapon_slot": ws, "owner_slot": shooter.slot, "attacker": shooter.net_id,
		"armor_pierce": float(prof["armor_pierce"]), "shield_pierce": bool(prof["shield_pierce"]),
		"radius_m": float(ex.get("radius_m", 0.0)), "arm_distance_m": float(ex.get("arm_distance_m", 0.0)),
		"retrievable": bool(pr.get("retrievable", false)), "pickup_radius_m": float(pr.get("pickup_radius_m", 1.0)),
		"despawn_s": float(pr.get("despawn_s", 60.0)), "impact_cue": impact_cue,
	}
	parent.add_child(proj, true)
	proj.global_position = origin
	NetIds.claim(proj)
	return proj


static func _in_cone(origin: Vector3, fwd: Vector3, point: Vector3, range_m: float, cos_half: float) -> bool:
	var to: Vector3 = point - origin
	var d: float = to.length()
	if d > range_m:
		return false
	return d < 0.3 or to.normalized().dot(fwd) >= cos_half


## The point of `target`'s vertical body axis nearest the ray origin + fwd * s (s >= 0); the centre for non-bodies.
static func _axis_point(target: Object, origin: Vector3, fwd: Vector3) -> Vector3:
	var body: CharacterBody3D = target as CharacterBody3D
	if body == null:
		return _center(target, origin)
	var a: Vector3 = body.global_position + Vector3.UP * AXIS_LOW_M
	var b: Vector3 = body.global_position + Vector3.UP * AXIS_HIGH_M
	var best: Vector3 = a
	var best_d: float = INF
	for i: int in AXIS_SAMPLES + 1:
		var p: Vector3 = a.lerp(b, float(i) / float(AXIS_SAMPLES))
		var to: Vector3 = p - origin
		var along: float = maxf(to.dot(fwd), 0.0)
		var d: float = (to - fwd * along).length()
		if d < best_d:
			best_d = d
			best = p
	return best


static func _center(target: Object, fallback: Vector3) -> Vector3:
	var body: CharacterBody3D = target as CharacterBody3D
	if body != null:
		return CombatSystem.target_center(body)
	var n3: Node3D = target as Node3D
	return n3.global_position if n3 != null else fallback
