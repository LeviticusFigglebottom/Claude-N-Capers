## Server-side hit-claim validation and damage helpers (A1-08, L3.8, architecture.md §3). Owner: ENV A.
##
## Every player shot becomes a HIT CLAIM, produced by the shooter's CrewWeapons (locally on the
## server for solo/host/AI/bots, on the owning client for remote humans, sent by RPC):
##   { "seq": int, "weapon_slot": int (Enums.WeaponSlot), "weapon_id": StringName,
##     "origin": Vector3, "direction": Vector3,
##     "hits": [ { "target_id": int, "zone": int (Enums.HitZone), "distance": float, "position": Vector3,
##                 "limb": StringName (optional, D-123 NpcLimbHitboxes.SUB_*: flinch sub-zone, never damage),
##                 "target": Object (server-local claims only; stripped before an RPC) } ] }
## `hits` holds one entry per pellet that struck a damageable hitbox (empty = miss/world hit).
## validate_and_apply() checks (in order) the shooter's state (S1.1 casing, CUSTODY...), shot seq,
## weapon slot, rate of fire, ammo, origin; consumes the round, emits weapon_fired + the S4.3 noise,
## then per hit: target resolves (object ref / net id / server re-raycast), range, distance sanity,
## hit point near a character target, LOS ray (world layers) - and delivers ONE
## `target.take_hit(Damage.info(...), shooter_net_id)` (docs/contracts/damage.md, D-026).
##
## Headshots (damage.md QB-26): `info.amount` is BODY damage; `info.headshot_bonus` =
## WeaponStats.headshot_mult (a bonus, default 1.0) x weapon.headshot_mult modifiers. The target
## applies its own zone multiplier (NpcBase: EnemyDef.headshot_mult[difficulty] x headshot_bonus).
## Targets emit damage_applied themselves; this file never does.
##
## D-118 shotgun ammo (ShotgunAmmo, CrewWeapons.ammo_profile): a claim carries at most
## CrewWeapons.pellet_count hits (the client fires exactly that many pellets; extra hits are dropped);
## slug / AP params feed pierce_profile; HE turns each pellet hit into Explosion.apply at the hit point;
## flechette / dragon's breath put a DoT (BurnStatus) on the NPCs hit; dragon's breath panics civilians.
class_name CombatSystem
extends RefCounted

const REJECT_NONE: StringName = &""
## DamageInfo flags guaranteed by ensure_info_v11() (damage.md v1.1).
const V11_FLAGS: Array[String] = ["pierced_armor", "shield_pierce", "blocked", "crit"]


## Server: validate a claim from `shooter` and apply it. Returns
## { "accepted": bool, "reason": StringName, "results": Array[Dictionary] (resolved DamageInfo per hit) }.
static func validate_and_apply(claim: Dictionary, shooter: CrewController) -> Dictionary:
	var out: Dictionary = {"accepted": false, "reason": REJECT_NONE, "results": [] as Array[Dictionary]}
	if not Net.is_authority() or shooter == null or not is_instance_valid(shooter):
		out["reason"] = &"not_authority"
		return out
	var w: CrewWeapons = shooter.weapons
	if w == null:
		out["reason"] = &"no_weapons"
		return out
	var reason: StringName = w.server_check_shot(claim)
	if reason != REJECT_NONE:
		out["reason"] = reason
		Log.debug(&"combat", "slot %d claim rejected: %s" % [shooter.slot, reason])
		return out
	w.server_commit_shot(claim)
	out["accepted"] = true
	var tw: CombatTweak = CombatTweak.data()
	var origin: Vector3 = claim.get("origin", shooter.eye_position())
	var ws: int = int(claim.get("weapon_slot", w.equipped_slot))
	var special: Dictionary = SpecialWeapons.params_for(shooter, ws)
	var tally: Dictionary = {"hit": false, "head": false, "victims": []}  # D-071: at most once per shot
	if SpecialWeapons.kind_of(special) != SpecialWeapons.KIND_HITSCAN:  # B4-18: flame / saw / projectile
		out["results"] = SpecialWeapons.server_apply(shooter, ws, claim, special)
		for r: Variant in out["results"]:
			var victim: Object = (r as Dictionary).get("victim") as Object if r is Dictionary else null
			if victim != null and is_instance_valid(victim) and CrewStatsService.enemy_of(victim) != null:
				tally["hit"] = true
		CrewStatsService.record_shot(shooter, bool(tally["hit"]), false)
		return out
	var hits: Array = claim.get("hits", [])
	var pellets: int = w.pellet_count(ws)
	if hits.size() > pellets:  # D-118: never more hits than the (ammo-resolved) pellets of one shot
		Log.debug(&"combat", "slot %d claim: %d hits > %d pellets, extra dropped" % [shooter.slot, hits.size(), pellets])
		hits = hits.slice(0, pellets)
	hits = validate_head_zones(shooter, origin, hits)  # L3.3 lead ruling: server checks claimed HEAD
	if pellets > 1:
		hits = pellet_headshots(hits)  # L3.3
	var results: Array[Dictionary] = []
	var hit_npcs: Array = []
	for h: Variant in hits:
		var hit: Dictionary = h as Dictionary
		if hit == null:
			continue
		var res: Dictionary = _apply_hit(shooter, w, ws, origin, hit, StringName(claim.get("weapon_id", &"")), tw,
			hit_npcs, tally)
		if not res.is_empty():
			results.append(res)
	out["results"] = results
	CrewStatsService.record_shot(shooter, bool(tally["hit"]), bool(tally["head"]))
	_near_misses(shooter, w, ws, claim, origin, hit_npcs)  # A3-06 (L3.5)
	var ammo: Dictionary = w.ammo_profile(ws)
	if bool(ammo.get("panic_civilians", false)):  # D-118 dragon's breath
		var dir_v: Variant = claim.get("direction")
		var dir: Vector3 = dir_v as Vector3 if dir_v is Vector3 else shooter.aim_direction()
		ShotgunAmmo.panic_civilians(shooter, origin, dir, ammo, tally["victims"] as Array)
	return out


static func _apply_hit(shooter: CrewController, w: CrewWeapons, ws: int, origin: Vector3,
		hit: Dictionary, weapon_id: StringName, tw: CombatTweak, hit_npcs: Array = [], tally: Dictionary = {}) -> Dictionary:
	var pos: Vector3 = hit.get("position", origin)
	var target: Object = _claimed_target(shooter, origin, hit)
	if target == null:
		return {}
	var dist: float = origin.distance_to(pos)
	if dist > tw.hitscan_max_range_m:
		return {}
	if absf(dist - float(hit.get("distance", dist))) > tw.claim_distance_tolerance_m:
		return {}
	var body: CharacterBody3D = target as CharacterBody3D
	if body != null and not _near_over_lag(pos, target_center(body), body, shooter, tw.claim_target_tolerance_m):
		return {}
	if not has_los(shooter, origin, pos, [shooter, target]):
		return {}
	var prof: Dictionary = pierce_profile(shooter, ws)
	var amount: float = w.damage_at(ws, dist)
	# A3-06 (L3.4): a thin wall (layer bullet_penetrable) on the line stops non-wall-pierce rounds.
	var through_wall: bool = not has_los(shooter, origin, pos, [shooter, target], tw.penetrable_mask)
	if through_wall and not bool(prof["wall_pierce"]):
		return {}
	if through_wall:
		amount *= tw.wall_pierce_damage_mult
	var ammo: Dictionary = w.ammo_profile(ws)
	if float(ammo.get("explosion_radius_m", 0.0)) > 0.0:  # D-118 HE: the pellet explodes where it hit
		return _apply_he(shooter, pos, amount * float(ammo["explosion_damage_mult"]), float(ammo["explosion_radius_m"]),
			weapon_id, tally)
	var info: Dictionary = Damage.info(amount, Enums.DamageType.BULLET,
		int(hit.get("zone", Enums.HitZone.BODY)), weapon_id, pos, (pos - origin).normalized(), shooter.net_id)
	info["headshot_bonus"] = w.headshot_bonus(ws)
	if SkillTriggers.roll_crit(shooter):  # B2: crit chance (skills, Unseen Strike); the target applies it (QB-29)
		info["crit"] = true
	info["amount"] = float(info["amount"]) * mark_damage_mult(target as Node, dist)  # B6 Price Tag
	var be: float = body_expertise_frac(shooter.slot, weapon_id, int(info["zone"]))  # B4b Anatomy: NpcBase applies it
	if be > 0.0:
		info["body_expertise"] = be
	info["pierced_armor"] = roll_armor_pierce(float(prof["armor_pierce"]))
	info["shield_pierce"] = bool(prof["shield_pierce"])
	info["blocked"] = false
	info["wall_pierced"] = through_wall
	info["range_m"] = dist  # PO6-19: shotgun pellets push bodies only at close range
	var limb: StringName = NpcLimbHitboxes.sanitize(hit.get("limb"), int(info["zone"]))
	if limb != &"":
		info["limb"] = limb  # D-123: the limb box's flinch sub-zone (damage is the BODY hit's)
	var npc: NpcBase = target as NpcBase
	var was_corpse: bool = npc != null and not npc.alive
	var res: Dictionary = deliver_hit(target, info, shooter.net_id)
	if tally.has("victims"):
		(tally["victims"] as Array).append(target)
	if npc != null and npc.alive:
		ShotgunAmmo.apply_dot(npc, shooter.net_id, weapon_id, ammo)  # D-118 flechette bleed / dragon's breath fire
	if was_corpse:
		return res  # PO6-19: a shot corpse bleeds and moves (NpcBase) but is no hit for stats or suppression
	if CrewStatsService.enemy_of(target) != null:  # D-071: body, shield or plate, even for 0 damage
		tally["hit"] = true
		if int(info["zone"]) == Enums.HitZone.HEAD and target is NpcBase:
			tally["head"] = true
	if npc != null and float(prof["suppression"]) > 0.0:  # A3-06 (L3.5): damage builds threat
		hit_npcs.append(npc)
		if float(res.get("amount", 0.0)) > 0.0:
			NpcSuppression.add_threat(npc, float(prof["suppression"]) * tw.threat_per_suppression_hit, origin)
	return res


## B6: the crew's damage multiplier on `target` at `dist` m from its marker's skills (StealthDirector marks):
## stealth.mark_damage_bonus_mult (Price Tag) x stealth.mark_far_damage_mult {min_distance, mult} beyond min_distance
## (Aced). 1 when unmarked.
static func mark_damage_mult(target: Node, dist: float) -> float:
	var rt: HeistRuntime = HeistRuntime.of(target) if target != null else null
	if rt == null or rt.stealth == null or not rt.stealth.is_marked(target):
		return 1.0
	var by: int = int((rt.stealth._marks.get(NetIds.of(target), {}) as Dictionary).get("by_slot", -1))
	var mult: float = Modifiers.mult(by, &"stealth.mark_damage_bonus_mult")
	var far: Dictionary = Modifiers.params(by, &"stealth.mark_far_damage_mult")
	if not far.is_empty() and dist >= float(far.get("min_distance", 0.0)):
		mult *= float(far.get("mult", 1.0))
	return mult


## B4b `weapon.body_expertise` {frac, auto_only, classes} (Anatomy): the share of the target's headshot multiplier a
## BODY hit from `slot`'s `weapon_id` gets (0: none); auto_only = weapons with a full-auto mode.
static func body_expertise_frac(slot: int, weapon_id: StringName, zone: int) -> float:
	var p: Dictionary = Modifiers.params(slot, &"weapon.body_expertise")
	var def: WeaponDef = ContentDB.weapon(weapon_id) if not p.is_empty() and ContentDB.has(ContentDB.WEAPONS, weapon_id) else null
	if p.is_empty() or def == null or zone != Enums.HitZone.BODY \
			or not (p.get("classes", []) as Array).has(String(Enums.weapon_class_qualifier(def.weapon_class))) \
			or (bool(p.get("auto_only", false)) and not def.fire_modes.has(&"auto")):
		return 0.0
	return float(p.get("frac", 0.0))


## D-118 HE pellet: Explosion.apply at the hit point (the blast replaces the bullet hit). Returns the
## blast's first result (its victims tally as hits), {} when it hurt nothing.
static func _apply_he(shooter: CrewController, pos: Vector3, damage: float, radius: float, weapon_id: StringName,
		tally: Dictionary) -> Dictionary:
	var blast: Array[Dictionary] = Explosion.apply(shooter, pos, radius, damage, shooter.net_id, weapon_id)
	for r: Dictionary in blast:
		if CrewStatsService.enemy_of(r.get("victim") as Object) != null:
			tally["hit"] = true
	return blast[0] if not blast.is_empty() else {}


## L3.3: for a multi-pellet shot, any pellet on the head makes every pellet of that shot on the same
## target a headshot. Returns copies of the hit dictionaries (the claim is left as sent).
static func pellet_headshots(hits: Array) -> Array:
	var head_keys: Dictionary = {}
	for h: Variant in hits:
		if h is Dictionary and int((h as Dictionary).get("zone", Enums.HitZone.BODY)) == Enums.HitZone.HEAD:
			var k: String = _hit_target_key(h as Dictionary)
			if k != "":
				head_keys[k] = true
	if head_keys.is_empty():
		return hits
	var out: Array = []
	for h: Variant in hits:
		if not h is Dictionary:
			out.append(h)
			continue
		var d: Dictionary = (h as Dictionary).duplicate()
		if head_keys.has(_hit_target_key(d)):
			d["zone"] = Enums.HitZone.HEAD
		out.append(d)
	return out


## L3.3 (lead ruling 2026-10-12): a claimed HEAD hit on an NpcBase stands only when the claimed point
## lies within CombatTweak.claim_head_tolerance_m of the NPC's head point; otherwise it is downgraded
## to BODY. Returns copies (the claim is left as sent). Non-NPC targets keep their zone.
static func validate_head_zones(shooter: CrewController, origin: Vector3, hits: Array) -> Array:
	var tol: float = CombatTweak.data().claim_head_tolerance_m
	var out: Array = []
	for h: Variant in hits:
		if not h is Dictionary or int((h as Dictionary).get("zone", Enums.HitZone.BODY)) != Enums.HitZone.HEAD:
			out.append(h)
			continue
		var d: Dictionary = (h as Dictionary).duplicate()
		var npc: NpcBase = _claimed_target(shooter, origin, d) as NpcBase if shooter != null else null
		if npc != null:
			var pos: Vector3 = d.get("position", origin)
			if not _near_over_lag(pos, npc.head_position(), npc, shooter, tol):
				d["zone"] = Enums.HitZone.BODY
		out.append(d)
	return out


## Identity of a claimed hit's target: the net id, else the local object's instance id ("" = unknown:
## re-raycast targets without an id are never upgraded).
static func _hit_target_key(hit: Dictionary) -> String:
	var tid: int = int(hit.get("target_id", 0))
	if tid != 0:
		return "id:%d" % tid
	var obj: Variant = hit.get("target")
	if obj is Object and is_instance_valid(obj):
		return "obj:%d" % (obj as Object).get_instance_id()
	return ""


## A3-06 (L3.4/L3.5): the piercing/threat profile of `shooter`'s weapon in slot `ws`:
## { armor_pierce: chance 0..1 (WeaponStats.armor_pierce + weapon.armor_pierce_add), shield_pierce: bool
## (WeaponStats.shield_pierce or weapon.shield_pierce), wall_pierce: bool, suppression: float (0 when
## the weapon is suppressed, L3.5) }.
static func pierce_profile(shooter: CrewController, ws: int) -> Dictionary:
	var out: Dictionary = {"armor_pierce": 0.0, "shield_pierce": false, "wall_pierce": false, "suppression": 0.0}
	var w: CrewWeapons = shooter.weapons if shooter != null else null
	var st: WeaponStats = w.stats(ws) if w != null else null
	if st == null:
		return out
	var def: WeaponDef = ContentDB.weapon(w.weapon_id(ws))
	var q: StringName = Enums.weapon_class_qualifier(def.weapon_class) if def != null else &"pistol"
	var ammo: Dictionary = w.ammo_profile(ws)  # D-118: slug / AP shotgun ammo
	var ap: float = maxf(st.armor_pierce, float(ammo.get("armor_pierce", 0.0)))
	out["armor_pierce"] = clampf(ap + Modifiers.add(shooter.slot, &"weapon.armor_pierce_add", q), 0.0, 1.0)
	out["shield_pierce"] = st.shield_pierce or bool(ammo.get("shield_pierce", false)) \
		or Modifiers.flag(shooter.slot, &"weapon.shield_pierce", q)
	out["wall_pierce"] = w.wall_pierce(ws)
	out["suppression"] = 0.0 if st.suppressed else st.suppression
	return out


## L3.4: does a round with armor-pierce chance `chance` pierce (GameRng &"armor_pierce")?
static func roll_armor_pierce(chance: float) -> bool:
	if chance >= 1.0:
		return true
	return chance > 0.0 and GameRng.stream(&"armor_pierce").randf() < chance


## A3-06 (L3.5): near-miss threat of one accepted shot along the claim's aim ray (up to the first world
## surface), for every suppressible NPC that was not hit by it.
static func _near_misses(shooter: CrewController, _w: CrewWeapons, ws: int, claim: Dictionary,
		origin: Vector3, hit_npcs: Array) -> void:
	var sup: float = float(pierce_profile(shooter, ws)["suppression"])
	var dir: Variant = claim.get("direction")
	if sup <= 0.0 or not dir is Vector3 or (dir as Vector3).length() < 0.001:
		return
	var tw: CombatTweak = CombatTweak.data()
	var end: Vector3 = origin + (dir as Vector3).normalized() * tw.hitscan_max_range_m
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end, tw.los_mask | tw.penetrable_mask)
	q.exclude = [shooter.get_rid()]
	var hit: Dictionary = shooter.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		end = hit.get("position", end)
	NpcSuppression.near_misses(shooter, origin, end, sup, hit_npcs)


## Target of a claimed hit: the local object reference (server-made claims), the net id, or a
## server re-raycast toward the claimed point (targets without a net id, e.g. ENV B range targets).
static func _claimed_target(shooter: CrewController, origin: Vector3, hit: Dictionary) -> Object:
	var obj: Variant = hit.get("target")
	if obj is Object and is_instance_valid(obj) and can_take_hit(obj as Object):
		return obj as Object
	var by_id: Node = Ids.lookup(int(hit.get("target_id", 0)))
	if by_id != null and can_take_hit(by_id):
		return by_id
	var pos: Vector3 = hit.get("position", origin)
	var seg: Vector3 = pos - origin
	if seg.length() < 0.01:
		return null
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, pos + seg.normalized() * 0.1, CombatTweak.data().hitscan_mask)
	q.collide_with_areas = true
	q.exclude = [shooter.get_rid()]
	var res: Dictionary = shooter.get_world_3d().direct_space_state.intersect_ray(q)
	return resolve_collider(res.get("collider")) if not res.is_empty() else null


## The object receiving hits for a physics collider (damage.md: Damage.find_target), falling back to
## the legacy `hit_owner` meta (pre-D-026 prefabs) when no `take_hit` receiver is found.
static func resolve_collider(collider: Variant) -> Object:
	var col: Object = collider as Object if collider is Object else null
	if col == null:
		return null
	var t: Object = Damage.find_target(col)
	if t != null:
		return t
	if col.has_meta(&"hit_owner"):
		var legacy: Object = col.get_meta(&"hit_owner") as Object
		if legacy != null and is_instance_valid(legacy) and can_take_hit(legacy):
			return legacy
	return null


static func can_take_hit(o: Object) -> bool:
	return o != null and (o.has_method(&"take_hit") or o.has_method(&"apply_damage"))


## The single hit call (damage.md): `target.take_hit(info, attacker)` once; the target emits
## damage_applied itself. Legacy targets with only `apply_damage` are called through it.
static func deliver_hit(target: Object, info: Dictionary, attacker_net_id: int) -> Dictionary:
	ensure_info_v11(info)
	var r: Variant = null
	if target.has_method(&"take_hit"):
		r = target.call(&"take_hit", info, attacker_net_id)
	elif target.has_method(&"apply_damage"):
		r = target.call(&"apply_damage", info, attacker_net_id)
	return r as Dictionary if r is Dictionary else info


## Damage.info (damage.md) plus the A1-08 extension `bypass_armor_gate` (snipers, L2.2).
static func make_damage_info(amount: float, type: int, zone: int, weapon_id: StringName, position: Vector3,
		direction: Vector3, bypass_armor_gate: bool = false, attacker_net_id: int = 0) -> Dictionary:
	var d: Dictionary = Damage.info(amount, type, zone, weapon_id, position, direction, attacker_net_id)
	d["bypass_armor_gate"] = bypass_armor_gate
	return ensure_info_v11(d)


## damage.md v1.1 keys on a DamageInfo (in place; returns it): `shield_pierce` (attacker: the round
## passes ballistic shields at the shield's shield_pierce_mult) and `blocked` (target: a shield or
## immunity stopped the hit, amount 0) default to false, `pierced_armor` / `crit` too. Damage.info()
## (LEAD helper) may not carry them yet; every A target calls this on its final_info.
static func ensure_info_v11(d: Dictionary) -> Dictionary:
	for k: String in V11_FLAGS:
		if not d.has(k):
			d[k] = false
	return d


## L3.2 falloff multiplier: 1 up to start, linear to min_mult at end (min_mult > 1 = snipers gain).
static func falloff_mult(stats: WeaponStats, distance: float) -> float:
	if stats == null or distance <= stats.falloff_start_m:
		return 1.0
	if distance >= stats.falloff_end_m or stats.falloff_end_m <= stats.falloff_start_m:
		return stats.falloff_min_mult
	var t: float = (distance - stats.falloff_start_m) / (stats.falloff_end_m - stats.falloff_start_m)
	return lerpf(1.0, stats.falloff_min_mult, t)


## Centre of mass of a character node (NPC or crew) for claim tolerance and NPC aim.
## P6: `pos` within `tol` of `point` (a spot on `target` now), or of where that spot was on a remote `shooter`'s
## screen (NetRewind: its interpolation delay + half its round trip); host / AI shooters use the present only.
static func _near_over_lag(pos: Vector3, point: Vector3, target: Node3D, shooter: CrewController, tol: float) -> bool:
	for off: Vector3 in NetRewind.offsets_for(target, shooter):
		if pos.distance_to(point + off) <= tol:
			return true
	return false


static func target_center(target: Node3D) -> Vector3:
	return target.global_position + Vector3(0.0, 0.9, 0.0)


## True when nothing on the world layers blocks `from` -> `to` (excluding the given bodies).
## `mask` -1 = CombatTweak.los_mask (A3-06: callers may pass e.g. penetrable_mask).
static func has_los(ctx: Node3D, from: Vector3, to: Vector3, exclude_nodes: Array = [], mask: int = -1) -> bool:
	var tw: CombatTweak = CombatTweak.data()
	var seg: Vector3 = to - from
	if seg.length() < 0.01:
		return true
	var end: Vector3 = to - seg.normalized() * minf(0.05, seg.length() * 0.5)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, end, tw.los_mask if mask < 0 else mask)
	var ex: Array[RID] = []
	for n: Variant in exclude_nodes:
		var co: CollisionObject3D = n as CollisionObject3D
		if co != null and is_instance_valid(co):
			ex.append(co.get_rid())
	q.exclude = ex
	return ctx.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## A3-06 (L4.5): NPC line of sight: like has_los, but Bulwark shields (group BulwarkShield.GROUP) never
## block NPCs (their own shield, or an ally's they stand behind).
static func has_npc_los(ctx: Node3D, from: Vector3, to: Vector3, exclude_nodes: Array = []) -> bool:
	var ex: Array = exclude_nodes.duplicate()
	if ctx != null and ctx.is_inside_tree():
		ex.append_array(ctx.get_tree().get_nodes_in_group(BulwarkShield.GROUP))
	return has_los(ctx, from, to, ex)
