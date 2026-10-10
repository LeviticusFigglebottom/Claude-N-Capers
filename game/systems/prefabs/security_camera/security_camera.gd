## Security camera observer (gameplay_prefabs.md `security_camera`). Owner: ENV A.
## Wall/ceiling mounted: pivot back-centre (wall) or top-centre (ceiling), view along -Z.
## Visual: `Mount` (static), `Head` (A yaws/pitches it), `Lens` (Marker3D, -Z = view direction),
## `Led` (MeshInstance3D, A toggles emission). Not interactive (shot to destroy when `destructible`).
## `Collision` is a small hitbox (layer hitboxes) so it can be shot.
class_name SecurityCamera
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/security_camera/security_camera_placeholder.tscn")

## Horizontal field of view (degrees).
@export var fov_deg: float = 60.0
@export var range_m: float = 20.0
## Total pan arc (degrees). 0 = static.
@export var pan_deg: float = 0.0
## Seconds for a full pan cycle.
@export var pan_period_s: float = 8.0
@export var destructible: bool = true

var active: bool = true


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Mount", "Head", "Lens", "Led"])


func _prefab_ready() -> void:
	# A1-03 behaviour (M2): observer registration (A1-04), pan, Led emission, destruction,
	# camera_disabled / cameras_loop_disabled handling.
	pass
