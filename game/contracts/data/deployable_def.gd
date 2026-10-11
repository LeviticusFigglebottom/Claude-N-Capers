## Deployables: ammo bag, doctor bag, first-aid kit, ECM, trip mine, sentry, body bag case.
class_name DeployableDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: StringName = &""         ## &"ammo_bag", &"doctor_bag", &"fak", &"ecm", &"trip_mine", &"sentry", &"body_bag_case"
@export var count: int = 1
@export var uses: int = 1                  ## charges per unit (doctor bag 2, ammo 4 (=400%) ...)
@export var deploy_time_s: float = 1.0
@export var params: Dictionary = {}        ## kind-specific (ecm: {duration}, sentry: {ammo, damage, armor}, ...)
@export var model: PackedScene
## D-069: first-person AnimationLibrary (characters.md v1.7): &"deploy_bag" | &"deploy_small" | &"deploy_sentry".
@export var anim_set: StringName = &"deploy_bag"
