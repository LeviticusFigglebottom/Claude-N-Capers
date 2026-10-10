## STOPGAP range tooling (B1-05), NOT gameplay: a debug hitscan driven by LoadoutResolver-resolved
## WeaponStats so the range works before ENV A's weapon runtime exists. DELETE when A1-08 lands
## (the range then spawns ENV A's crew controller, whose real weapon hits RangeTarget through the
## damage.md single hit path). Owner: ENV B.
##
## Rate of fire, magazine, tactical/empty reload, ADS/hip spread cone (rolled on
## GameRng.stream(&"range")), per-pellet rays, falloff by distance (RangeMath) and the shotgun
## "any pellet on the head" rule. Infinite reserve ammo (range). No recoil, no skills.
class_name RangeDebugGun
extends RefCounted

## world_static (layer 1) + hitboxes (layer 5), project.godot layer names.
const RAY_MASK: int = 1 | RangeHitbox.LAYER_HITBOXES
const RNG_STREAM: StringName = &"range"

var weapon_id: StringName = &""
var stats: WeaponStats = null
var automatic: bool = false
var ammo: int = 0
var max_range_m: float = 250.0

var _cooldown: float = 0.0
var _reload_left: float = 0.0


func equip(id: StringName, resolved: WeaponStats, is_automatic: bool) -> void:
	weapon_id = id
	stats = resolved
	automatic = is_automatic
	ammo = maxi(stats.mag_size, 1) if stats != null else 0
	_cooldown = 0.0
	_reload_left = 0.0


func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			ammo = maxi(stats.mag_size, 1)


func is_reloading() -> bool:
	return _reload_left > 0.0


func can_fire() -> bool:
	return stats != null and ammo > 0 and _cooldown <= 0.0 and not is_reloading()


## Tactical reload (rounds left) or empty reload.
func reload() -> void:
	if stats == null or is_reloading() or ammo >= stats.mag_size:
		return
	_reload_left = stats.reload_time_s if ammo > 0 else stats.reload_empty_time_s
	_reload_left = maxf(_reload_left, 0.01)


## Fire one shot from `origin` along `aim` (-Z of the basis). Returns the final infos of the hits
## (`take_hit` results, each with `distance_m`). Empty when it could not fire or missed.
## Hits follow docs/contracts/damage.md: targets/zones come from Damage.find_target/zone_of and
## each pellet calls `take_hit` exactly once with body damage after falloff.
func fire(space: PhysicsDirectSpaceState3D, origin: Vector3, aim: Basis, ads: bool, attacker_net_id: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not can_fire():
		return out
	ammo -= 1
	_cooldown = RangeMath.shot_interval_s(stats)
	var spread: float = deg_to_rad(stats.spread_deg_ads if ads else stats.spread_deg_hip)
	var rng: RandomNumberGenerator = GameRng.stream(RNG_STREAM)
	var hits: Array[Dictionary] = []
	var head_targets: Array[Object] = []
	for i: int in range(maxi(stats.pellets, 1)):
		var dir: Vector3 = cone_direction(aim, spread, rng.randf(), rng.randf())
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range_m, RAY_MASK)
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			continue
		var collider: Object = hit.get("collider") as Object
		var target: Object = Damage.find_target(collider)
		if target == null:
			continue
		var zone: int = Damage.zone_of(collider)
		var pos: Vector3 = hit["position"]
		hits.append({"target": target, "zone": zone, "position": pos, "direction": dir, "distance": origin.distance_to(pos)})
		if zone == Enums.HitZone.HEAD and not head_targets.has(target):
			head_targets.append(target)
	if ammo <= 0:
		reload()
	for h: Dictionary in hits:
		var target: Object = h["target"]
		# Shotguns: any pellet on the head makes every pellet on that target a headshot (L3.3).
		var zone: int = Enums.HitZone.HEAD if head_targets.has(target) else int(h["zone"])
		var info: Dictionary = make_info(stats, weapon_id, float(h["distance"]), zone, h["position"], h["direction"], attacker_net_id)
		var applied: Dictionary = target.call(&"take_hit", info, attacker_net_id)
		if not applied.is_empty():
			out.append(applied)
	return out


## DamageInfo (Damage.info, contracts/damage.md) for one pellet: body damage after falloff; the
## target applies its zone multiplier x `headshot_bonus` (the weapon headshot bonus).
## `distance_m` is an extra key for the range readout.
static func make_info(s: WeaponStats, id: StringName, distance_m: float, zone: int, pos: Vector3, dir: Vector3,
		attacker_net_id: int = 0) -> Dictionary:
	var info: Dictionary = Damage.info(RangeMath.pellet_damage(s, distance_m), Enums.DamageType.BULLET, zone,
			id, pos, dir, attacker_net_id)
	info["headshot_bonus"] = s.headshot_mult
	info["pierced_armor"] = s.armor_pierce > 0.0
	info["distance_m"] = distance_m
	return info


## Uniform direction inside a cone of half-angle `spread_rad` around -Z of `aim`.
static func cone_direction(aim: Basis, spread_rad: float, u: float, v: float) -> Vector3:
	var theta: float = spread_rad * sqrt(u)
	var phi: float = TAU * v
	var local: Vector3 = Vector3(sin(theta) * cos(phi), sin(theta) * sin(phi), -cos(theta))
	return (aim * local).normalized()
