# Contract: groups and ids (v1.0)

All group names and service names are constants in `game/contracts/ids.gd` (class `G`). Never type
the literal strings. Map-placed groups are added automatically by the contract node scripts in
`game/contracts/map/` (SpawnPoint, MapZone, TacticalPoint, VariantSlot, PatrolGraph).

Id formats (StringName): `weapon.<name>`, `mod.<name>`, `melee.<name>`, `throwable.<name>`,
`deploy.<name>`, `armor.<name>`, `skill.<tree>.<name>`, `perk.<deck>`, `loot.<name>`, `item.<name>`,
`enemy.<name>`, `cue.<name>`, `vo.<speaker>.<name>`, `asset.<name>`, `heist id` = bare snake_case.
