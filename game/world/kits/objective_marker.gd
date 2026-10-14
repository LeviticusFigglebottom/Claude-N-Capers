## Tagged map marker (Gallery Night rehearsal F5). Owner: ENV C.
## A Marker3D that carries an `objective_tag`, so `HeistRuntime.find_by_tag` and the HUD's objective markers
## (LocalHudModel, ui_hud 1.8) resolve it like a gameplay prefab: both read the `objective_tag` property, which a
## plain Marker3D (meta only) does not have. For objectives that point at a place, not a prefab (Gallery Night
## `casing_hall`, B5), and for greybox placeholders of tagged prefabs until the prefab replaces them. No behaviour,
## no Interactable: validate_level only walks to it through a `UsePoint` child.
extends Marker3D

@export var objective_tag: StringName = &""
