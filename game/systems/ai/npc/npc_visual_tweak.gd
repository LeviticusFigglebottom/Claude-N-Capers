## PO-5.7 (D-089): which ENV D character an NPC wears when its EnemyDef has no `visual` (NpcVisuals).
## Values are character ids (res://world/characters/<id>/<id>.tscn, characters.json). Owner: ENV A.
class_name NpcVisualTweak
extends Resource

## EnemyDef id -> character id when it is not the id's `enemy.<id>` suffix (Aegis wears bulwark_aegis, the
## Wrecker weapon variants wear wrecker). The faction variant (params.visual_variant) still applies.
@export var enemy_characters: Dictionary = {}
## SpawnPoint tag -> character ids (first matching tag wins; the pick is stable per NPC name).
@export var tag_characters: Dictionary = {}
## NPC role (&"civilian", &"guard", ...) -> character ids when no tag matched and no EnemyDef applies.
@export var role_characters: Dictionary = {}
