## Ammo box drops and pickups (QB-57, PD2 enemy ammo drops). Owner: ENV A. Data: ammo_pickup_tweak.tres.
## Rounds per box come from ENV B's WeaponStats.ammo_pickup_min/max; ◇ = design value.
class_name AmmoPickupTweak
extends Resource

const PATH: String = "res://systems/combat/ammo_pickup_tweak.tres"

static var _cached: AmmoPickupTweak = null

@export_group("Drops")
## Chance that a killed NPC drops an ammo box (PD2: every enemy drops one).
@export var drop_chance: float = 1.0
## NPC roles that never drop ammo.
@export var no_drop_roles: Array[StringName] = [&"civilian"]
## Drop height above the NPC origin (m).
@export var drop_height_m: float = 0.1
## Oldest boxes are removed beyond this many in one heist ◇.
@export var max_boxes: int = 64

@export_group("Pickup")
## Walk-over radius (m, horizontal) ◇ before weapon.ammo_pickup_range_mult.
@export var pickup_radius_m: float = 1.0
## Max height difference between the box and the crew origin (m) ◇.
@export var pickup_height_m: float = 1.2


static func data() -> AmmoPickupTweak:
	if _cached == null:
		_cached = load(PATH) as AmmoPickupTweak
		if _cached == null:
			_cached = AmmoPickupTweak.new()
	return _cached
