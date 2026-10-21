## A5-01 armored truck (Rolling Thunder QC-80; rolling_thunder.md "Truck targets"). Owner: ENV A.
## A vehicle-shaped Safe LARGE: the rear doors are the safe's `Door` (front, -Z), the lock is its `DrillPoint`
## marker, the cargo (`loot_spawn` children) lives inside and is enabled when the doors open (Safe PO6-05).
## Opened by any one method: a placed saw (the safe's own SAW runner, or a SAW drill_point child targeting it,
## PO6-01: one visible saw), the handheld saw (G.SAW_TARGET, `hand_saw_duration_s`), C4 (`charges_required`, 4 by
## default), or a burn_point whose `target` is the truck (QC-81: the bullion truck's rear-door thermite).
## Defaults in armored_truck.tscn (cash van, design ◇): saw 120 s, hand saw 60 s; the bullion truck sets 180 / 90.
## `lockdown()` (the early alarm, D-149.9: original, not PD2-sourced): saw times x
## InteractionTweak.truck_lockdown_saw_mult, placed and by hand, for devices not yet placed; C4 and thermite unchanged.
## Visual: `Body` (cargo box, fits the collision), `Door` (rear doors, pivot at the hinge), `DrillPoint`, `LootAnchor`;
## optional `Cab`. Pivot bottom-centre, rear doors on -Z, the cab toward +Z.
class_name ArmoredTruck
extends Safe

const TRUCK_PLACEHOLDER: PackedScene = preload("res://systems/prefabs/armored_truck/armored_truck_placeholder.tscn")
const GROUP: StringName = &"armored_truck"

## True once lockdown() ran (server; the mission replicates the effect through device run times).
var locked_down: bool = false


func _placeholder_scene() -> PackedScene:
	return TRUCK_PLACEHOLDER


func _prefab_ready() -> void:
	super._prefab_ready()
	add_to_group(GROUP)


## Server (A5-01, the early alarm): deadbolts thrown. Saws not yet placed on this truck (its own runner, every SAW
## drill_point targeting it) and the handheld saw take truck_lockdown_saw_mult longer. Idempotent.
func lockdown() -> void:
	if not Net.is_authority() or locked_down or opened:
		return
	locked_down = true
	var mult: float = Tweak.interaction().truck_lockdown_saw_mult
	saw_time_mult = mult
	for dp: DrillPoint in saw_points():
		dp.duration_mult = mult
	Log.info(LOG_CHANNEL, "%s: lockdown (saw x%.2f)" % [name, mult])


## SAW drill_points whose `target` is this truck (children or anywhere in the map).
func saw_points() -> Array[DrillPoint]:
	var out: Array[DrillPoint] = []
	for n: Node in get_tree().get_nodes_in_group(G.SAW_TARGET):
		var dp: DrillPoint = n as DrillPoint
		if dp != null and dp.device == DrillPoint.Device.SAW and not dp.target.is_empty() \
				and dp.get_node_or_null(dp.target) == self:
			out.append(dp)
	return out
