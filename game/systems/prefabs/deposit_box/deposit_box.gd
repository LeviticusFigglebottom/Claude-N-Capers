## Safe-deposit box (QC-37; Night Deposit vault walls): small loot locked until the handheld saw cuts it
## open (G.SAW_TARGET, `saw_cut`, InteractionTweak.hand_saw_deposit_box_s). Owner: ENV A.
## Opened: the SmallLoot interaction (take_loot) is enabled; small_loot_taken(value, slot) [R] as usual.
class_name DepositBox
extends SmallLoot

const BOX_PLACEHOLDER: PackedScene = preload("res://systems/prefabs/deposit_box/deposit_box_placeholder.tscn")

var opened: bool = false
var saw_progress: float = 0.0


func _placeholder_scene() -> PackedScene:
	return BOX_PLACEHOLDER


func _prefab_ready() -> void:
	super()
	add_to_group(G.SAW_TARGET)
	interactable.enabled = opened


## Server (QC-37): the handheld saw cut the box for `seconds`.
func saw_cut(seconds: float, _attacker_net_id: int) -> void:
	if not Net.is_authority() or opened:
		return
	saw_progress = minf(saw_progress + seconds / maxf(Tweak.interaction().hand_saw_deposit_box_s, 0.01), 1.0)
	if saw_progress >= 1.0 - 0.0001:
		opened = true
		interactable.enabled = true
