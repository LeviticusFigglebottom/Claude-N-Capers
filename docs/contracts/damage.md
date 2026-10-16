# Contract: damage and hits (v1.3)

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

## v1.2 (PO6-19, D-114 §7): corpse hits and ragdoll triggers
ENV A (env/a-core f16e1031; `NpcBase._corpse_hit`, `NpcRagdoll`, tunables `RagdollTweak` in
`game/systems/anim/ragdoll_tweak.tres`, all ◇ presentation tuning).
* **Corpse hits.** A dead NPC keeps one `CorpseHitbox` (a `Hitbox` on layer 5 `hitboxes`, zone `BODY`, a box lying along
  the body; NpcRagdoll moves it to where the body rests). The ragdoll's own bodies (layer 11 `ragdoll`, characters.md
  v1.12) are never hit-tested. A bullet, melee or blast on a corpse still goes through `take_hit`, which on a dead NPC
  deals **no damage**, emits **no** `damage_applied` / `npc_killed`, and instead (server) emits `blood_hit` at the hit
  point (D-113, `killed = false`) and **nudges** the ragdoll: it restarts from the baked pose with impulse = live-hit
  impulse × `nudge_mult` 0.5, clamped to `nudge_min..nudge_max` 5–20 N·s, and re-freezes after `nudge_settle_s` 1 s.
  Bagged bodies take nothing. Blasts push corpses in radius and LOS (`Explosion.push_corpses`, × `corpse_blast_mult`
  0.5, no blood). A frozen corpse moved more than `bleed_move_m` 0.5 m restarts its blood pool where it lies.
* **Not a hit.** `CombatSystem._apply_hit` returns before the D-071 tally and suppression when the target was already a
  corpse: a corpse hit counts for no `hits` / `headshots` stat and builds no threat (L3.5).
* **Ragdoll at death** (server decides; only for NPCs whose visual has `Skeleton3D/Ragdoll`, capsule placeholders keep
  the animation-only death). The hits of the killing physics frame are summed (all pellets of a shotgun shot):
  * an **explosion** kill always ragdolls (`explosion_always`; every body pushed outward, upper body weighted so it tips);
  * a summed hit impulse **≥ `min_impulse` 90 N·s** ragdolls at once from the current pose. Per-hit impulses
    (`bullet_impulse_by_class`, N·s): pistol 12, smg 10, ar 16, lmg 18, sniper 70, shotgun 25 **per pellet** within
    `shotgun_range_m` 6 m (× `shotgun_far_mult` 0.25 beyond); melee 25. A point-blank shotgun blast ≈ 250 N·s;
  * otherwise the pose-aware death clip (PO6-18) plays (waited at most `anim_wait_max_s` 3 s), then a
    `settle_after_anim_s` **1 s** settle ragdoll lays the body on the floor.
* **Freeze and cap.** A ragdoll freezes (bones baked, simulation stopped) after `settle_s` **3 s**, or earlier once
  every body is slower than `settle_speed_mps` 0.05 (not before `settle_min_s` 0.6 s). At most `max_active` **8**
  ragdolls simulate per peer; starting one more freezes the oldest first. Replication: net.md v1.2 (`"rs"`, `"rp"`).

## v1.3: limb hitboxes (D-123)
Rigged NPCs carry four bone-following capsules (upper_arm.L/R, thigh.L/R). A limb hit reports zone BODY, so the 1.0
multiplier, headshot, armor, stats and kill-info rules are unchanged. The hit claim and DamageInfo may carry an optional
`limb` key (&"shoulder_l" / &"shoulder_r" / &"leg_l" / &"leg_r"), used only to pick the flinch clip. The server drops it on
HEAD hits and drops unknown values. `Enums.HitZone.LIMB` stays unused by NPC hitboxes.
