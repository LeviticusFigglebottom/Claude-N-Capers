## PO-5.7 (D-089): which ENV D character an NPC wears when its EnemyDef has no `visual` (NpcVisuals).
## Values are character ids (res://world/characters/<id>/<id>.tscn, characters.json). Owner: ENV A.
class_name NpcVisualTweak
extends Resource

## EnemyDef id -> character id when it is not the id's `enemy.<id>` suffix (Aegis wears bulwark_aegis, the
## Wrecker weapon variants wear wrecker). The faction variant (params.visual_variant) still applies.
@export var enemy_characters: Dictionary = {}
## SpawnPoint tag -> character ids (first matching tag wins; the pick is stable per NPC name).
@export var tag_characters: Dictionary = {}
## D-103 §3b.1: heist id -> {SpawnPoint tag -> character ids}, checked before tag_characters so a heist can dress a
## tag another heist already uses (Gallery Night's guard_hall wears gallery_guard, Night Deposit's does not).
@export var heist_tag_characters: Dictionary = {}
## LEAD (D's DB/SL cast audit): heist id -> {SpawnPoint tag -> pool name}. Tags of one pool share a single
## round-robin deal (and must list the same ids), so e.g. every Shadow Ledger guard post plus the operator wear no
## twins while their live count <= the pool's looks. An unmapped tag is its own pool.
@export var heist_tag_pools: Dictionary = {}
## NPC role (&"civilian", &"guard", ...) -> character ids when no tag matched and no EnemyDef applies.
@export var role_characters: Dictionary = {}
