## Shotgun AMMO mods (D-118, visual_slots.md v1.3): the resolved WeaponDef.params (SpecialWeapons.params_of)
## carry `ammo_type` (&"slug", &"he", &"flechette", &"dragons_breath"; absent = buckshot) plus per-type params.
## ENV B owns the values; missing keys fall back to CombatTweak.shotgun_ammo_defaults[type], then clamp. Owner: ENV A.
## Runtime (server-authoritative through CombatSystem; the client claim uses the same pellet count):
## * pellets / pellets_mult: pellets per shot (CrewWeapons.pellet_count; slug = 1).
## * armor_pierce (0..1, max with WeaponStats), shield_pierce (or), penetration (overrides wall_pierce; HE = false).
## * explosion_radius_m / explosion_damage_mult (HE): each pellet hit becomes an Explosion.apply at the hit point.
## * dot_dps / dot_s: DoT on NPCs hit (BurnStatus); `ignite` = fire (dragon's breath), else a bleed (flechette).
## * panic_civilians: civilians in the shot cone or hit panic (CivilianBrain.panic).
## * range_mult: scales the falloff distances (and the panic cone range). ammo_pickup_mult: ammo box rounds.
class_name ShotgunAmmo
extends RefCounted

const BUCKSHOT: StringName = &""
const SLUG: StringName = &"slug"
const HE: StringName = &"he"
const FLECHETTE: StringName = &"flechette"
const DRAGONS_BREATH: StringName = &"dragons_breath"
const TYPES: Array[StringName] = [SLUG, HE, FLECHETTE, DRAGONS_BREATH]
## Bleed DoT (flechette): its own status node next to `Burn`, ticking DamageType.POISON (no blood, ignores armor).
const BLEED_NODE: String = "Bleed"
## Params read from the resolved WeaponDef.params (or the tweak defaults).
const KEYS: Array[String] = ["pellets", "pellets_mult", "armor_pierce", "shield_pierce", "explosion_radius_m",
	"explosion_damage_mult", "penetration", "dot_dps", "dot_s", "ignite", "panic_civilians", "range_mult",
	"ammo_pickup_mult"]


static func type_of(p: Dictionary) -> StringName:
	var t: StringName = StringName(str(p.get("ammo_type", "")))
	return t if TYPES.has(t) else BUCKSHOT


## Resolved, clamped ammo profile of merged params `p` (every key present; buckshot = neutral values).
static func profile(p: Dictionary) -> Dictionary:
	var tw: CombatTweak = CombatTweak.data()
	var t: StringName = type_of(p)
	var src: Dictionary = {}
	if t != BUCKSHOT:
		var d: Variant = tw.shotgun_ammo_defaults.get(String(t), {})
		if d is Dictionary:
			src = (d as Dictionary).duplicate()
	for k: String in KEYS:
		if p.has(k):
			src[k] = p[k]
	var out: Dictionary = {"ammo_type": t}
	out["pellets"] = clampi(int(src.get("pellets", 0)), 0, tw.shotgun_ammo_max_pellets)  # 0 = keep WeaponStats
	out["pellets_mult"] = clampf(float(src.get("pellets_mult", 1.0)), 0.0, float(tw.shotgun_ammo_max_pellets))
	out["armor_pierce"] = clampf(float(src.get("armor_pierce", 0.0)), 0.0, 1.0)
	out["shield_pierce"] = bool(src.get("shield_pierce", false))
	out["has_penetration"] = src.has("penetration")
	out["penetration"] = bool(src.get("penetration", false))
	out["explosion_radius_m"] = clampf(float(src.get("explosion_radius_m", 0.0)), 0.0, tw.shotgun_ammo_max_explosion_radius_m)
	out["explosion_damage_mult"] = clampf(float(src.get("explosion_damage_mult", 1.0)), 0.0,
		tw.shotgun_ammo_max_explosion_damage_mult)
	out["dot_dps"] = clampf(float(src.get("dot_dps", 0.0)), 0.0, tw.shotgun_ammo_max_dot_dps)
	out["dot_s"] = clampf(float(src.get("dot_s", 0.0)), 0.0, tw.shotgun_ammo_max_dot_s)
	out["ignite"] = bool(src.get("ignite", false))
	out["panic_civilians"] = bool(src.get("panic_civilians", false))
	out["range_mult"] = clampf(float(src.get("range_mult", 1.0)), tw.shotgun_ammo_range_mult_min, tw.shotgun_ammo_range_mult_max)
	out["ammo_pickup_mult"] = clampf(float(src.get("ammo_pickup_mult", 1.0)), 0.0, tw.shotgun_ammo_max_pickup_mult)
	return out


## Pellets per shot for a weapon of `base` pellets under profile `prof` (at least 1).
static func pellets(base: int, prof: Dictionary) -> int:
	var b: int = maxi(base, 1)
	if prof.is_empty():
		return b
	var n: int = int(prof.get("pellets", 0))
	if n <= 0:
		n = int(round(float(b) * float(prof.get("pellets_mult", 1.0))))
	return clampi(n, 1, maxi(CombatTweak.data().shotgun_ammo_max_pellets, 1))


## Wall piercing: the ammo's `penetration` when it sets one, else the weapon's own.
static func wall_pierce(stats_wall_pierce: bool, prof: Dictionary) -> bool:
	return bool(prof.get("penetration", false)) if bool(prof.get("has_penetration", false)) else stats_wall_pierce


## Server: the DoT of profile `prof` on an NPC that was hit (fire burn with `ignite`, else a bleed).
static func apply_dot(npc: NpcBase, attacker_net_id: int, weapon_id: StringName, prof: Dictionary) -> BurnStatus:
	if npc == null or not npc.alive or float(prof.get("dot_dps", 0.0)) <= 0.0 or float(prof.get("dot_s", 0.0)) <= 0.0:
		return null
	var dot: Dictionary = {"dot_damage_per_s": float(prof["dot_dps"]), "dot_duration_s": float(prof["dot_s"])}
	if bool(prof.get("ignite", false)):
		return BurnStatus.ignite(npc, attacker_net_id, weapon_id, dot)
	return BurnStatus.ignite(npc, attacker_net_id, weapon_id, dot, Enums.DamageType.POISON, BLEED_NODE)


## Server: panic civilians (CivilianBrain.panic, the S3.1 path) within the shot cone of `shooter`, plus `hit` ones.
static func panic_civilians(shooter: CrewController, origin: Vector3, dir: Vector3, prof: Dictionary,
		hit: Array = []) -> int:
	if shooter == null or not shooter.is_inside_tree() or not Net.is_authority():
		return 0
	var tw: CombatTweak = CombatTweak.data()
	var range_m: float = tw.shotgun_panic_range_m * float(prof.get("range_mult", 1.0))
	var cos_half: float = cos(deg_to_rad(clampf(tw.shotgun_panic_cone_deg, 0.0, 179.0) * 0.5))
	var fwd: Vector3 = dir.normalized() if dir.length() > 0.0001 else shooter.aim_direction()
	var n: int = 0
	for node: Node in shooter.get_tree().get_nodes_in_group(G.CIVILIAN):
		var npc: NpcBase = node as NpcBase
		if npc == null or not npc.alive:
			continue
		var c: Vector3 = CombatSystem.target_center(npc)
		var to: Vector3 = c - origin
		var in_cone: bool = to.length() <= range_m and (to.length() < 0.3 or to.normalized().dot(fwd) >= cos_half) \
			and CombatSystem.has_los(shooter, origin, c, [shooter, npc])
		if not in_cone and not hit.has(npc):
			continue
		var brain: CivilianBrain = npc.get_node_or_null(^"Brain") as CivilianBrain
		if brain != null:
			brain.panic(origin)
			n += 1
	return n
