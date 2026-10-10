# Contract: damage and hits (v1.1)

Producer of hits: ENV A (weapons, melee, explosives, sentries, NPC fire). Damage targets: ENV A
(crew, NPCs, cameras, glass, shields), ENV B (firing-range targets and armor dummies). Helper:
`game/contracts/damage.gd` (`Damage`).

## Hitboxes
* Physics layer **5 `hitboxes`** (bit 1<<4). Each hitbox is a body or area that implements
  `get_damage_target() -> Object` and `get_hit_zone() -> Enums.HitZone`. Simple targets without separate
  hitboxes implement `take_hit` on an ancestor of the collider. Resolve with `Damage.find_target(collider)`
  and `Damage.zone_of(collider)`.
* Weak points (Wrecker faceplate and visor) are hitboxes with zone `WEAKPOINT` whose target routes the hit
  to the plate's HP pool. They are owned by the target's implementation.

## The single hit path (answers QB-27)
* On the **server**, the attacker's system builds `info = Damage.info(...)` and calls exactly once
  `target.take_hit(info: Dictionary, attacker_net_id: int) -> Dictionary` and nothing else.
* `info.amount` is **body damage**: after range falloff and attacker-side modifiers
  (`weapon.damage_mult.*`, crits roll on the attacker side and set `crit` / `headshot_bonus`), and
  **before** zone, armor, shields and resistance.
* The **target** applies its own zone multiplier (e.g. `EnemyDef.headshot_mult[difficulty]`), armor
  or plates, the captain resistance and so on. It then emits `EventBus.damage_applied(victim_net_id,
  attacker_net_id, final_info)` (and `npc_killed` when relevant) **itself**, and returns `final_info`
  with the final `amount` and `killed`.
* Nobody else emits `damage_applied`, and targets never act on `damage_applied` events for their own
  damage (that would apply the hit twice).

## Headshot multiplier (answers QB-26)
* **Canonical:** the **target's** multiplier (`EnemyDef.headshot_mult[difficulty]`; range dummies copy
  the EnemyDef they imitate; crew members take ×1 on the head from NPC fire).
* `WeaponStats.headshot_mult` is redefined as a **weapon headshot bonus**, default **1.0**. It is put into
  `info.headshot_bonus` together with `weapon.headshot_mult` modifiers and the shared Headhunter perk
  card. For zone HEAD the target applies `zone_mult × headshot_bonus`. Shotguns: any pellet on the head
  counts (pd2_fidelity L3.3).

## Crits and weak points (v1.0 addendum, D-027)
* `info.crit = true` ⇒ the target additionally multiplies by its own HEAD zone multiplier on any zone. On a
  head hit the two stack (PD2 behaviour).
* Zone `WEAKPOINT` on a target without plates counts ×1. Firing-range dummies never emit `npc_killed`.

## Armor, shields and plates (v1.1, D-052; answers ENV B QB-a..d)
* Attacker side rolls and sets `pierced_armor` (the weapon's armor-piercing chance or AP ammo) and `shield_pierce`
  (the weapon can shoot through shields: AP rounds, sniper class, skills). Targets only read them.
* `pierced_armor` ⇒ the target ignores body armor / frontal armor reduction. `shield_pierce` ⇒ a shield hit passes
  through at the target's `shield_pierce_mult` (e.g. ×0.25) instead of being blocked.
* A blocked hit still goes through the single hit path: the target emits `damage_applied` with `amount` 0 and
  `blocked: true` (hit markers, stats), and returns that info.
* Plates (Wrecker faceplate/visor): plate damage uses ×1 zone, crits do not apply, excess damage beyond the
  plate's remaining HP is lost (PD2).
* Range dummies copy the EnemyDef they imitate (ENV A ships EnemyDefs for every special, incl. the armour
  params); ENV B's range data may reference EnemyDef resource paths (data, not code).
