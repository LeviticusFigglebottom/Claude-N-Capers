## Weapon stat block. Used both as base stats (WeaponDef.base) and mod deltas (WeaponModDef.delta),
## and as the RESOLVED stats ENV A's weapon code consumes. Owner: LEAD. Contract: data_schemas.md.
## Display stats (0..100-ish, PD2-style UI numbers) are derived from these physical values by
## ENV B's StatCalculator for UI only; gameplay uses the physical values below.
class_name WeaponStats
extends Resource

@export var damage: float = 0.0               ## per pellet/bullet, body hit, at close range
@export var pellets: int = 1
@export var headshot_mult: float = 1.0       ## weapon headshot BONUS (x target's zone mult), damage.md
@export var fire_rate_rpm: float = 0.0
@export var spread_deg_hip: float = 0.0       ## cone half-angle hip-fire
@export var spread_deg_ads: float = 0.0
@export var recoil_kick_deg: float = 0.0      ## stability: vertical kick per shot
@export var recoil_horizontal_deg: float = 0.0
@export var falloff_start_m: float = 20.0
@export var falloff_end_m: float = 40.0
@export var falloff_min_mult: float = 0.5
@export var mag_size: int = 0
@export var total_ammo: int = 0               ## reserve incl. magazine
@export var reload_time_s: float = 0.0        ## tactical reload
@export var reload_empty_time_s: float = 0.0
@export var equip_time_s: float = 0.5
@export var ads_time_s: float = 0.25
@export var concealment: int = 0              ## 0..30; contributes to detection risk
@export var armor_pierce: float = 0.0         ## 0..1
@export var shield_pierce: bool = false
@export var wall_pierce: bool = false
@export var suppression: float = 0.0          ## threat/suppression vs enemies
@export var ammo_pickup_min: float = 0.0      ## rounds per ammo pickup (before modifiers)
@export var ammo_pickup_max: float = 0.0
@export var suppressed: bool = false          ## silenced: stealth noise radius uses suppressed profile
@export var noise_radius_m: float = 60.0      ## alert radius of a shot (suppressed ~ 0-5 m)
@export var magnification: float = 1.0        ## ADS zoom
@export var gadgets: Array[StringName] = []   ## &"laser", &"flashlight", &"angled_sight"


## A zeroed stat block for mod deltas (all fields 0/false), so plus() never adds base defaults.
## ENV B must build every WeaponModDef.delta from this (answers QB-5).
static func make_delta() -> WeaponStats:
	var d: WeaponStats = WeaponStats.new()
	d.pellets = 0
	d.headshot_mult = 0.0
	d.falloff_start_m = 0.0
	d.falloff_end_m = 0.0
	d.falloff_min_mult = 0.0
	d.equip_time_s = 0.0
	d.ads_time_s = 0.0
	d.noise_radius_m = 0.0
	d.magnification = 0.0
	return d


## Additive combination used for mods. Multiplicative fields documented in data_schemas.md.
func plus(d: WeaponStats) -> WeaponStats:
	var r: WeaponStats = duplicate() as WeaponStats
	r.damage += d.damage
	r.pellets += d.pellets
	r.fire_rate_rpm += d.fire_rate_rpm
	r.spread_deg_hip += d.spread_deg_hip
	r.spread_deg_ads += d.spread_deg_ads
	r.recoil_kick_deg += d.recoil_kick_deg
	r.recoil_horizontal_deg += d.recoil_horizontal_deg
	r.falloff_start_m += d.falloff_start_m
	r.falloff_end_m += d.falloff_end_m
	r.mag_size += d.mag_size
	r.total_ammo += d.total_ammo
	r.reload_time_s += d.reload_time_s
	r.reload_empty_time_s += d.reload_empty_time_s
	r.concealment += d.concealment
	r.armor_pierce += d.armor_pierce
	r.shield_pierce = r.shield_pierce or d.shield_pierce
	r.suppressed = r.suppressed or d.suppressed
	r.wall_pierce = r.wall_pierce or d.wall_pierce
	r.suppression += d.suppression
	r.magnification = maxf(r.magnification, d.magnification)
	r.ads_time_s += d.ads_time_s
	r.equip_time_s += d.equip_time_s
	if d.suppressed:
		r.noise_radius_m = minf(r.noise_radius_m, d.noise_radius_m)
	for g: StringName in d.gadgets:
		if not r.gadgets.has(g):
			r.gadgets.append(g)
	return r
