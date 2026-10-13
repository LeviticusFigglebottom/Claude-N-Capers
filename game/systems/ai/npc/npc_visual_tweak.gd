## PO-5.7 (D-089): which ENV D character an NPC wears when its EnemyDef has no `visual` (NpcVisuals).
## Values are character ids (res://world/characters/<id>/<id>.tscn, characters.json). Owner: ENV A.
class_name NpcVisualTweak
extends Resource

## SpawnPoint tag -> character ids (first matching tag wins; the pick is stable per NPC name).
@export var tag_characters: Dictionary = {}
## NPC role (&"civilian", &"guard", ...) -> character ids when no tag matched and no EnemyDef applies.
@export var role_characters: Dictionary = {}
