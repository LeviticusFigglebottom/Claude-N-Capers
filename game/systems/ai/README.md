# systems/ai (ENV A)

NPC framework (`npc/`), police / guards / civilians, crew AI, specials and their data
(`data/enemies/*.tres`, `EnemyDef`). Target-side hit rules live in `systems/combat/npc_hit_rules.gd`
(`NpcHitRules`), the hit contract in `docs/contracts/damage.md`.

## Armour params (D-052, damage.md v1.1)

One canonical set of `EnemyDef.params` keys describes how an enemy's armour treats a hit. **Every**
EnemyDef under `data/enemies/` (including the `frd/`, `sentinel/`, `zero/` variants) carries the complete
set, so ENV B's range dummies can copy the EnemyDef they imitate. Read them through
`NpcHitRules.armor_of(def: EnemyDef) -> Dictionary`: it returns every key below (with defaults) and
still accepts the pre-D-052 names for old data.

| Key | Type | Default | Meaning (target side) | Was |
|---|---|---|---|---|
| `armor_body_mult` | float | 1.0 | Generic body armour (L3.4): a non-armour-piercing BULLET on BODY / LIMB (outside the frontal arc) deals × this. Fire, explosions, melee and `info.pierced_armor` ignore it. | `body_armor_mult` |
| `frontal_armor` | float | 1.0 | Frontal armour (L4.2 TAC Heavy): a non-AP BULLET on BODY / LIMB coming from inside `frontal_armor_arc_deg` deals × this (0 = stopped). The head stays vulnerable. `pierced_armor` ignores it. | `frontal_plate_mult` |
| `frontal_armor_arc_deg` | float | 0.0 | Full width of the frontal arc around the NPC's facing; 0 = no frontal armour. | `frontal_plate_arc_deg` |
| `explosive_mult` | float | 1.0 | DamageType.EXPLOSION multiplier (L3.6 / L4.6 Wrecker × 1.1). | (same) |
| `shield` | bool | false | Carries a ballistic shield (Bulwark / Aegis). The shield is its own hit target (`BulwarkShield`). | (new; Aegis had it) |
| `shield_pierce_mult` | float | 1.0 (0.25 on shield carriers) | A `info.shield_pierce` BULLET passes the shield and hits what is behind at × this. Without shield_pierce the hit is **blocked**. FIRE passes at `CombatTweak.shield_fire_damage_mult`. Unused when `shield` is false. | `CombatTweak.shield_pierce_damage_mult` (still the fallback) |
| `plate_health` | Array[float] | [] | Weak-point plates in break order: Wrecker `[faceplate, visor]` = `[150, 160]` on every difficulty. While a plate stands the head is armoured (HEAD hits ×1, no crit). | `faceplate_hp`, `visor_hp` |

Current values: TAC Heavy `frontal_armor` 0.0 in a 120° arc; Bulwark and the Aegis placeholder
`shield` true, `shield_pierce_mult` 0.25; every Wrecker variant `explosive_mult` 1.1 and
`plate_health` [150, 160]; everything else at the defaults.

### Hit resolution order (NpcBase.take_hit, server)

1. `explosive_mult` (explosions).
2. HEAD: armoured head (plates up) = ×1 and `head_armored`; otherwise BODY / LIMB BULLET without
   `pierced_armor`: `frontal_armor` inside the arc, else `armor_body_mult`.
3. HEAD zone: × `EnemyDef.headshot_mult[difficulty]` × `info.headshot_bonus`.
4. `info.crit`: × the HEAD multiplier on any zone (stacks on a head hit); cleared on an armoured head.
5. Captain resistance / per-hit cap (AegisCaptain), then health, Corpsman save, `damage_applied` [R].

Plates (`WreckerArmor`, zone WEAKPOINT): the body amount ×1 (no zone multiplier, no headshot bonus, no
crit), only the current plate; damage beyond its remaining HP is lost; explosions do not hit plates;
`damage_applied` carries `plate`, `plate_hp_left`, `plate_broken` and `amount` = HP the plate lost.

Shields (`BulwarkShield`): blocked hit = `damage_applied(carrier net id (0 when dropped), attacker,
info)` with `amount` 0 and `blocked` true; a pierced hit is forwarded once to the target behind (which
emits its own `damage_applied` with `shield_pierced` true).

### DamageInfo v1.1 keys

Attacker side (`CombatSystem`): `pierced_armor` (rolled from `WeaponStats.armor_pierce` +
`weapon.armor_pierce_add`, GameRng stream `armor_pierce`), `shield_pierce` (`WeaponStats.shield_pierce`
or the `weapon.shield_pierce` flag). Target side: `blocked`. Every ENV A target returns a final_info
with `pierced_armor`, `shield_pierce`, `blocked` and `crit` present (`CombatSystem.ensure_info_v11`).
