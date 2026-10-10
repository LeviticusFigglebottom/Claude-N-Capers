## Perk point rate (pd2_fidelity P4; D-034 QB-45). Data: res://content/data/tweak/perk_points.tres
## (ContentDB.tweak(&"perk_points")). Owner: ENV B. Read by PerkProgress.earned().
## Perk points are earned from ALL XP: earned = floor(PlayerProfile.xp / xp_per_perk_point). Earned
## points are derived, never stored, so changing the rate re-prices old profiles.
class_name PerkPointTweak
extends Resource

const TWEAK: StringName = &"perk_points"

## ◇ Accepted by D-034 (QB-45); the rate is ours, not PD2's. 0 or less = no perk points.
@export var xp_per_perk_point: int = 500


## The data tweak, or schema defaults when the file is missing (ContentDB logs the error).
static func current() -> PerkPointTweak:
	var tw: PerkPointTweak = ContentDB.tweak(TWEAK) as PerkPointTweak
	return tw if tw != null else PerkPointTweak.new()
