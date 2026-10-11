## Target-side NPC hit rules (A3-06, A3-01b; damage.md v1.1). Owner: ENV A. Called only from
## NpcBase.take_hit on the server (docs/contracts/damage.md: the TARGET applies zone, armor, plates and
## resistances). Canonical EnemyDef.params armour keys (D-052; full table: systems/ai/README.md
## "Armour params"), read through armor_of(), which also accepts the pre-D-052 names:
## - `explosive_mult` (float, 1): DamageType.EXPLOSION multiplier (L4.6 Wrecker x1.1).
## - `frontal_armor` (float, 1 = none) inside `frontal_armor_arc_deg` (float, 0 = none): L4.2 TAC Heavy.
##   BULLET hits on BODY/LIMB coming from inside the frontal arc deal x frontal_armor unless the round
##   pierced armor (`info.pierced_armor`, L3.4). The head stays vulnerable. (was frontal_plate_mult /
##   frontal_plate_arc_deg)
## - `armor_body_mult` (float, 1): L3.4 generic body armor. Non-AP BULLET hits on BODY/LIMB (outside the
##   frontal arc) deal x armor_body_mult. Fire, explosions and melee ignore armor. (was body_armor_mult)
## - `shield` (bool) + `shield_pierce_mult` (float): BulwarkShield (its own node and hit path).
## - `plate_health` (Array[float], [] = none): WreckerArmor faceplate, visor (was faceplate_hp/visor_hp).
## - A child node `Weakpoints` with `is_head_armored() -> bool` (L4.6 WreckerArmor) turns HEAD hits
##   into x1 hits (no zone multiplier, no crit) while it returns true: `out.head_armored = true`.
## `lethal_intercept` runs when a hit would kill: L4.8 Corpsman revive (CorpsmanBrain.try_revive).
class_name NpcHitRules
extends RefCounted


## Canonical armour keys (D-052) -> default.
const ARMOR_DEFAULTS: Dictionary = {
	"armor_body_mult": 1.0, "frontal_armor": 1.0, "frontal_armor_arc_deg": 0.0, "explosive_mult": 1.0,
	"shield": false, "shield_pierce_mult": 1.0, "plate_health": [],
}
## Pre-D-052 names still read when the canonical key is missing.
const LEGACY_KEYS: Dictionary = {
	"armor_body_mult": "body_armor_mult", "frontal_armor": "frontal_plate_mult",
	"frontal_armor_arc_deg": "frontal_plate_arc_deg",
}


## The complete canonical armour set of `def` (ENV B range dummies read this too): every key of
## ARMOR_DEFAULTS, from params (canonical name, else the legacy one, else the default). A legacy
## TAC-Heavy-style frontal plate without a mult blocks (legacy default 0). `plate_health` falls back to
## [faceplate_hp, visor_hp]; `shield_pierce_mult` of a shield carrier falls back to
## CombatTweak.shield_pierce_damage_mult.
static func armor_of(def: EnemyDef) -> Dictionary:
	var p: Dictionary = def.params if def != null else {}
	var out: Dictionary = {}
	for k: String in ARMOR_DEFAULTS:
		if p.has(k):
			out[k] = p[k]
		elif LEGACY_KEYS.has(k) and p.has(LEGACY_KEYS[k]):
			out[k] = p[LEGACY_KEYS[k]]
		else:
			out[k] = ARMOR_DEFAULTS[k]
	if not p.has("frontal_armor") and not p.has("frontal_plate_mult") and float(out["frontal_armor_arc_deg"]) > 0.0:
		out["frontal_armor"] = 0.0
	if not p.has("plate_health") and (p.has("faceplate_hp") or p.has("visor_hp")):
		out["plate_health"] = [float(p.get("faceplate_hp", 150.0)), float(p.get("visor_hp", 160.0))]
	var plates: Array[float] = []
	for v: Variant in out["plate_health"] as Array:
		plates.append(float(v))
	out["plate_health"] = plates
	out["shield"] = bool(out["shield"])
	if bool(out["shield"]) and not p.has("shield_pierce_mult"):
		out["shield_pierce_mult"] = CombatTweak.data().shield_pierce_damage_mult
	for k: String in ["armor_body_mult", "frontal_armor", "frontal_armor_arc_deg", "explosive_mult", "shield_pierce_mult"]:
		out[k] = float(out[k])
	return out


## Adjusted body amount for `info` on `npc` (before the zone multiplier). May set out flags
## `head_armored`, `frontal_plate` (frontal armour hit), `armor_reduced`.
static func pre_zone(npc: NpcBase, info: Dictionary, amount: float, out: Dictionary) -> float:
	var a: Dictionary = armor_of(npc.enemy_def)
	var type: int = int(info.get("type", Enums.DamageType.BULLET))
	var zone: int = int(info.get("zone", Enums.HitZone.BODY))
	if type == Enums.DamageType.EXPLOSION:
		amount *= float(a["explosive_mult"])  # L3.6 / L4.6
	if zone == Enums.HitZone.HEAD:
		var wp: Node = npc.get_node_or_null("Weakpoints")
		if wp != null and wp.has_method(&"is_head_armored") and bool(wp.call(&"is_head_armored")):
			out["head_armored"] = true  # L4.6: headshot-immune until faceplate + visor are gone
		return amount
	if type != Enums.DamageType.BULLET or bool(info.get("pierced_armor", false)):
		return amount  # L3.4: AP rounds, fire and explosions ignore armor
	if zone != Enums.HitZone.BODY and zone != Enums.HitZone.LIMB:
		return amount
	var arc: float = float(a["frontal_armor_arc_deg"])
	if arc > 0.0 and is_from_front(npc, info, arc):
		out["frontal_plate"] = true  # L4.2 TAC Heavy frontal armour
		return amount * float(a["frontal_armor"])
	var armor_mult: float = float(a["armor_body_mult"])
	if armor_mult != 1.0:
		out["armor_reduced"] = true
	return amount * armor_mult


## True when the shot direction of `info` comes from within `arc_deg` around the NPC's facing.
static func is_from_front(npc: NpcBase, info: Dictionary, arc_deg: float) -> bool:
	var dir: Vector3 = info.get("direction", Vector3.ZERO)
	dir.y = 0.0
	if dir.length() < 0.001:
		var pos: Variant = info.get("position")
		if not pos is Vector3:
			return false
		dir = npc.global_position - (pos as Vector3)  # fall back: from the hit point inward
		dir.y = 0.0
		if dir.length() < 0.001:
			return false
	var toward_shooter: Vector3 = -dir.normalized()
	return toward_shooter.dot(npc.look_forward()) >= cos(deg_to_rad(arc_deg * 0.5))


## A hit would kill `npc`: true when something saved it (L4.8 Corpsman revive). The saver sets
## npc.health and out["healed_by"].
static func lethal_intercept(npc: NpcBase, out: Dictionary) -> bool:
	return CorpsmanBrain.try_revive(npc, out)
