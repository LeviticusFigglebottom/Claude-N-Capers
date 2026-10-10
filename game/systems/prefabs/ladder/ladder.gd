## Climbable ladder (S9.11). Owner: ENV A.
## Floor object: pivot bottom-centre, climb side -Z, wall/ledge at +Z.
## Visual: `Top` and `Bottom` markers (climb end points). The placeholder is resized to `height_m`.
class_name Ladder
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/ladder/ladder_placeholder.tscn")
## Height the placeholder is modelled at.
const PLACEHOLDER_HEIGHT_M: float = 3.0

@export var height_m: float = 3.0


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Top", "Bottom"])


func _prefab_ready() -> void:
	if using_placeholder:
		var rails: Node3D = visual_node("Rails") as Node3D
		if rails != null:
			rails.scale.y = height_m / PLACEHOLDER_HEIGHT_M
		var top: Node3D = visual_node("Top") as Node3D
		if top != null:
			top.position.y = height_m
	# A1-03 behaviour (M2): climb volume and CrewController climbing between Bottom and Top.
