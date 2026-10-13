## Loot bag tunables (S6.3, S10.1-S10.3). Owner: ENV A. Data: loot_tweak.tres.
## Crew-side bag numbers (speed, sprint/jump, throw distance) live in CrewTweak "Bags (S10.1)".
class_name LootTweak
extends Resource

const PATH: String = "res://systems/tweak/loot_tweak.tres"

static var _instance: LootTweak = null

@export_group("Loot table")
## Used when ContentDB has no LootDef for an id: id -> {"weight": Enums.LootWeight, "value": int}.
@export var fallback_loot: Dictionary = {
	&"loot.body_bag": {"weight": Enums.LootWeight.HEAVY, "value": 0},
}
## Weight/value of an id neither ContentDB nor `fallback_loot` knows.
@export var unknown_weight: Enums.LootWeight = Enums.LootWeight.MEDIUM
@export var unknown_value: int = 0
## S6.3: the bag a bagged body becomes.
@export var body_bag_loot_id: StringName = &"loot.body_bag"
## S6.3: body bags are HEAVY whatever the LootDef says.
@export var body_bag_weight: Enums.LootWeight = Enums.LootWeight.HEAVY
## Display case payout when its `loot_id` is empty or unknown.
@export var display_case_default_value: int = 1000

@export_group("Bag physics (S10.1)")
## Index by Enums.LootWeight.
@export var bag_mass_kg: PackedFloat32Array = PackedFloat32Array([6.0, 12.0, 20.0, 30.0])
## Bag box size (m) by Enums.LootWeight (pivot bottom, visual_slots.md).
@export var bag_size_m: PackedVector3Array = PackedVector3Array([
	Vector3(0.5, 0.3, 0.3), Vector3(0.6, 0.35, 0.35), Vector3(0.75, 0.4, 0.4), Vector3(0.85, 0.45, 0.45),
])
## Where a carried bag sits relative to the carrier's feet (+Z = behind).
@export var carry_offset: Vector3 = Vector3(0.0, 0.9, 0.35)
## Drop: placed this far in front of the carrier at this height (m).
@export var drop_forward_m: float = 0.7
@export var drop_height_m: float = 0.3
## Throw: released at this height above the carrier's feet with this elevation angle.
@export var throw_release_height_m: float = 1.3
@export var throw_elevation_deg: float = 25.0
## PO-5 (ENV P, PD2): the throw follows the camera pitch (lob over a fence / onto a van, drop short looking
## down). Launch elevation = clamp(look_pitch + bias, min, max); the speed stays the flat-ground speed above.
@export var throw_pitch_bias_deg: float = 25.0  # = throw_elevation_deg: looking level throws as before
@export var throw_min_elev_deg: float = -20.0
@export var throw_max_elev_deg: float = 70.0
## Fraction of velocity kept when a thrown bag first touches something (stops long slides).
@export var landing_velocity_keep: float = 0.15
@export var friction: float = 1.0
@export var bounce: float = 0.0

@export_group("Securing and hiding (S10.2, S6.3)")
## A bag resting inside a SECURE_LOOT zone this long is secured.
@export var secure_rest_s: float = 0.5
## Below this speed a bag counts as resting (m/s).
@export var rest_speed_mps: float = 0.25
## Zone probe height above the bag origin (m).
@export var zone_probe_up_m: float = 0.15


static func get_default() -> LootTweak:
	if _instance == null:
		_instance = load(PATH) as LootTweak
		if _instance == null:
			_instance = LootTweak.new()
	return _instance
