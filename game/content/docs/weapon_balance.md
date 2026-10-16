# Weapon balance audit (D-115, ENV B): stock builds vs PD2 shapes

Status: **analysis only, nothing applied.** Same method as D-120: every number is derived from data, compared with
PD2 *shapes* (no exact PD2 numbers invented). The proposals at the end are base-stat edits to weapon `.tres` files and
wait for LEAD approval.
Tool: `/opt/godot/godot --headless --path game -s res://content/progression/tools/weapon_balance_cli.gd -- [difficulty] [out.md]`
(the default is 5 = Cataclysm). It regenerates the tables and the mechanical flags below.

## Method and assumptions

* **Stock build** = `LoadoutResolver.resolve_weapon(id, [])` (base + `default_mods`) passed through `AmmoStats.apply`
  (none of the stock builds load a non-buckshot shell). Accuracy and stability come from `StatCalculator.display`.
* **Enemies** (ENV A data, read only): `systems/ai/data/enemies/tac_heavy.tres` (PD2 heavy SWAT) and `wrecker.tres`
  (PD2 Bulldozer; `wrecker_b/g/s` share its HP, while `wrecker_m` has 2x). HP is indexed by `Enums.Difficulty`
  (ROUTINE..CATACLYSM). Difficulty scaling lives only in `EnemyDef.health[d]`, because `DifficultyDef` has no HP
  multiplier. At Cataclysm: TAC Heavy **640 HP**, head x3; Wrecker **24000 HP**, head x2.5, plates 150/160 on every difficulty.
* **Damage rules** come from `docs/contracts/damage.md` v1.3, `NpcHitRules.pre_zone`, `NpcBase.take_hit`, `WreckerArmor.take_hit` and `SpecialWeapons`:
  * Head = body x target `headshot_mult[d]` x weapon `headshot_mult` bonus (1.0 for every stock weapon). For shotguns,
    every pellet that hits the head gets the multiplier.
  * TAC Heavy frontal plate: a non-AP bullet on BODY/LIMB inside the 120 deg front arc does **x0**, while the head stays
    open. "Heavy front body" shows that case (AP chance p gives a p x damage expectation). "Heavy flank body" assumes
    hits from outside the arc. Fire, saw (`pierced_armor = true`) and explosions ignore the plate.
  * Wrecker "head" route: each bullet or pellet takes x1 off the current plate (faceplate, then visor), and damage past
    what the plate has left is lost. The next pellet of the same shot hits the next stage. After both plates break,
    the head takes x2.5. Wrecker "body" route: x1, explosions x1.1. Explosions never hit plates. Flame, saw and blasts
    always land as BODY.
* **TTK** counts shots and seconds from a full mag at point blank, with every shot and pellet hitting. It leaves out
  skills, crits, falloff, spin-up and draw time. Shot k fires at `floor(k/mag) x cycle + (k mod mag) x 60/rpm`, where
  `cycle = (mag-1) x 60/rpm + max(60/rpm, empty reload)`.
  A trailing `!` means the kill needs more rounds than the full reserve.
* **Sustained DPS** = per-shot damage x mag / cycle (empty reload). The flamethrower adds its 15/s burn.
  The bow's 0.8 s draw is assumed to overlap its 1 s cycle, so its 400 DPS may be an overestimate.
* **Ammo economy** = total ammo / shots to kill a TAC Heavy (head) and average pickup / shots to kill (rounds per box,
  with no skills).
* **Pickup floor**: `AmmoPickupSystem` returns `maxi(round(n), 1)`, so every box gives at least 1 round. A `min` below 1
  only matters through rounding, and the Thumper's 0.2-0.4 really gives 1 grenade per box.

## Per-class tables (Cataclysm, stock)

Targets: TAC Heavy 640 HP (head x3.0, frontal plate x0.0 in 120 deg); Wrecker 24000 HP (head x2.5, plates [150.0, 160.0]).

### pistol

| weapon | slot | lvl | dmg (pellet) | dmg@20m | rpm | mag/total | acc | stab | conc | reload t/e | pickup | AP(+S shield) | DPS | Heavy head | Heavy flank body | Heavy front body | Wrecker head | Wrecker body | ammo/kill | pickup/kill |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| kestrel_p9 | S | 0 | 35 | 29 | 480 | 17/153 | 52 | 78 | 30 | 1.50/2.10 | 4.0-8.0 | 0.00 | 145 | 7/0.75s | 19/4.22s | blocked | 285/67.10s! | 686/164.62s! | 21.9 | 0.86 |
| wren_380 | S | 2 | 30 | 21 | 520 | 7/98 | 52 | 78 | 30 | 1.40/2.00 | 3.0-7.0 | 0.00 | 78 | 8/2.69s | 22/8.08s | blocked | 331/126.65s! | 800/307.04s! | 12.2 | 0.62 |
| sparrow_mp | S | 5 | 30 | 21 | 880 | 20/140 | 52 | 93 | 28 | 1.80/2.40 | 4.0-9.0 | 0.00 | 162 | 8/0.48s | 22/3.76s | blocked | 331/59.81s! | 800/145.42s! | 17.5 | 0.81 |
| warden_45 | S | 6 | 62 | 52 | 400 | 8/72 | 68 | 75 | 27 | 1.70/2.30 | 2.0-4.0 | 0.00 | 148 | 4/0.45s | 11/3.65s | blocked | 161/67.00s! | 388/161.25s! | 18.0 | 0.75 |
| marshal_357 | S | 10 | 155 | 146 | 330 | 6/54 | 76 | 58 | 26 | 2.40/2.40 | 1.0-3.0 | 0.00 | 281 | 2/0.18s | 5/0.73s | blocked | 65/33.82s! | 155/83.45s! | 27.0 | 1.00 |
| akimbo_warden_45 | P | 16 | 62 | 52 | 400 | 16/128 | 60 | 78 | 23 | 3.00/3.60 | 3.0-6.0 | 0.00 | 170 | 4/0.45s | 11/1.50s | blocked | 161/58.50s! | 388/140.85s! | 32.0 | 1.12 |

### smg

| weapon | slot | lvl | dmg (pellet) | dmg@20m | rpm | mag/total | acc | stab | conc | reload t/e | pickup | AP(+S shield) | DPS | Heavy head | Heavy flank body | Heavy front body | Wrecker head | Wrecker body | ammo/kill | pickup/kill |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ferret_9 | S | 3 | 40 | 35 | 600 | 32/192 | 52 | 85 | 23 | 2.30/3.00 | 6.0-12.0 | 0.00 | 210 | 6/0.50s | 16/1.50s | blocked | 248/45.00s! | 600/112.10s! | 32.0 | 1.50 |
| hornet_9 | S | 4 | 36 | 34 | 800 | 30/180 | 52 | 85 | 24 | 2.20/3.00 | 6.0-12.0 | 0.00 | 209 | 6/0.38s | 18/1.27s | blocked | 277/47.02s! | 667/114.30s! | 30.0 | 1.50 |
| wasp_pdw | S | 7 | 30 | 26 | 850 | 30/210 | 44 | 90 | 27 | 2.20/2.90 | 6.0-13.0 | 0.00 | 182 | 8/0.49s | 22/1.48s | blocked | 331/54.42s! | 800/129.96s! | 26.2 | 1.19 |
| mastiff_45 | S | 11 | 52 | 44 | 620 | 25/150 | 60 | 81 | 22 | 2.40/3.20 | 4.0-9.0 | 0.00 | 235 | 5/0.39s | 13/1.16s | blocked | 192/40.21s! | 462/100.47s! | 30.0 | 1.30 |
| hush_9 | S | 15 | 34 | 30 | 700 | 30/180 | 44 | 90 | 21 | 2.40/3.10 | 6.0-12.0 | 0.00 | 183 | 7/0.51s | 19/1.54s | blocked | 293/52.16s! | 706/129.76s! | 25.7 | 1.29 |
| lancet_45 | S | 22 | 46 | 38 | 880 | 25/150 | 60 | 83 | 22 | 2.30/3.00 | 5.0-10.0 | 0.00 | 248 | 5/0.27s | 14/0.89s | blocked | 217/38.18s! | 522/94.16s! | 30.0 | 1.50 |

### ar

| weapon | slot | lvl | dmg (pellet) | dmg@20m | rpm | mag/total | acc | stab | conc | reload t/e | pickup | AP(+S shield) | DPS | Heavy head | Heavy flank body | Heavy front body | Wrecker head | Wrecker body | ammo/kill | pickup/kill |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| corsair_ar | P | 3 | 55 | 55 | 700 | 30/150 | 44 | 85 | 20 | 2.40/3.10 | 4.0-9.0 | 0.00 | 295 | 4/0.26s | 12/0.94s | blocked | 181/33.51s! | 437/79.57s! | 37.5 | 1.62 |
| lark_carbine | P | 5 | 44 | 44 | 750 | 30/180 | 35 | 89 | 23 | 2.20/2.90 | 5.0-10.0 | 0.00 | 253 | 5/0.32s | 15/1.12s | blocked | 227/37.82s! | 546/94.36s! | 36.0 | 1.50 |
| drover_762 | P | 9 | 80 | 80 | 600 | 30/120 | 69 | 81 | 16 | 2.60/3.40 | 3.0-7.0 | 0.00 | 381 | 3/0.20s | 8/0.70s | blocked | 124/25.50s! | 300/59.60s! | 40.0 | 1.67 |
| tern_556 | P | 12 | 52 | 52 | 680 | 30/150 | 44 | 85 | 21 | 2.80/3.60 | 4.0-9.0 | 0.00 | 253 | 5/0.35s | 13/1.06s | blocked | 192/37.92s! | 462/93.35s! | 30.0 | 1.30 |
| falchion_dmr | P | 20 | 150 | 150 | 420 | 20/80 | 84 | 79 | 8 | 2.70/3.50 | 1.5-3.5 | 0.00 | 483 | 2/0.14s | 5/0.57s | blocked | 67/19.50s | 160/46.21s! | 40.0 | 1.25 |
| bastion_br | P | 24 | 100 | 100 | 550 | 20/100 | 69 | 81 | 11 | 2.70/3.50 | 2.0-5.0 | 0.00 | 359 | 3/0.22s | 7/0.65s | blocked | 100/24.36s | 240/63.37s! | 33.3 | 1.17 |

### shotgun

| weapon | slot | lvl | dmg (pellet) | dmg@20m | rpm | mag/total | acc | stab | conc | reload t/e | pickup | AP(+S shield) | DPS | Heavy head | Heavy flank body | Heavy front body | Wrecker head | Wrecker body | ammo/kill | pickup/kill |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| plowman_12 | P | 8 | 160 (16x10) | 43 | 70 | 6/48 | 40 | 62 | 21 | 3.40/4.20 | 1.0-3.0 | 0.00 | 113 | 2/0.86s | 4/2.57s | blocked | 62/85.71s! | 150/207.94s! | 24.0 | 1.00 |
| mule_12 | S | 13 | 130 (13x10) | 16 | 72 | 5/35 | 40 | 62 | 25 | 2.97/3.77 | 1.0-2.0 | 0.00 | 92 | 2/0.83s | 5/3.33s | blocked | 77/107.33s! | 185/258.93s! | 17.5 | 0.75 |
| reaper_db | P | 17 | 190 (19x10) | 52 | 300 | 2/40 | 60 | 44 | 18 | 2.40/2.40 | 1.0-2.0 | 0.00 | 146 | 2/0.20s | 4/2.80s | blocked | 53/67.60s! | 127/163.80s! | 20.0 | 0.75 |
| harrow_12 | P | 21 | 130 (13x10) | 16 | 300 | 8/56 | 27 | 68 | 16 | 2.90/3.60 | 1.0-3.0 | 0.00 | 208 | 2/0.20s | 5/0.80s | blocked | 77/45.80s! | 185/115.00s! | 28.0 | 1.00 |
| brute_12 | P | 30 | 110 (11x10) | 11 | 300 | 20/80 | 27 | 68 | 8 | 3.60/4.40 | 1.0-3.0 | 0.00 | 268 | 2/0.20s | 6/1.00s | blocked | 91/34.80s! | 219/85.60s! | 40.0 | 1.00 |

### lmg

| weapon | slot | lvl | dmg (pellet) | dmg@20m | rpm | mag/total | acc | stab | conc | reload t/e | pickup | AP(+S shield) | DPS | Heavy head | Heavy flank body | Heavy front body | Wrecker head | Wrecker body | ammo/kill | pickup/kill |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| rampart_lmg | P | 18 | 48 | 48 | 750 | 100/300 | 48 | 83 | 2 | 5.60/6.60 | 8.0-16.0 | 0.00 | 331 | 5/0.32s | 14/1.04s | blocked | 208/29.60s | 500/66.00s! | 60.0 | 2.40 |
| anvil_lmg | P | 26 | 64 | 64 | 600 | 100/250 | 48 | 83 | 1 | 6.00/7.00 | 6.0-12.0 | 0.00 | 379 | 4/0.30s | 10/0.90s | blocked | 156/22.40s | 375/58.10s! | 62.5 | 2.25 |
| gale_mg | P | 34 | 50 | 50 | 880 | 100/300 | 48 | 83 | 2 | 5.80/6.80 | 8.0-16.0 | 0.00 | 369 | 5/0.27s | 13/0.82s | blocked | 199/20.23s | 480/59.59s! | 60.0 | 2.40 |

### sniper

| weapon | slot | lvl | dmg (pellet) | dmg@20m | rpm | mag/total | acc | stab | conc | reload t/e | pickup | AP(+S shield) | DPS | Heavy head | Heavy flank body | Heavy front body | Wrecker head | Wrecker body | ammo/kill | pickup/kill |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| heron_308 | P | 14 | 230 | 230 | 50 | 5/40 | 88 | 22 | 6 | 3.00/3.80 | 1.0-2.0 | 1.00+S | 134 | 1/0.00s | 3/2.40s | 3/2.40s | 44/72.40s! | 105/176.80s! | 40.0 | 1.50 |
| shrike_44 | P | 19 | 180 | 180 | 75 | 8/48 | 92 | 16 | 16 | 4.40/4.90 | 1.0-2.5 | 1.00+S | 137 | 2/0.80s | 4/2.40s | 4/2.40s | 56/68.60s! | 134/172.00s! | 24.0 | 0.88 |
| osprey_762 | P | 28 | 160 | 160 | 140 | 10/50 | 92 | 51 | 5 | 2.90/3.70 | 1.0-2.5 | 1.00+S | 212 | 2/0.43s | 4/1.29s | 4/1.29s | 62/45.77s! | 150/109.66s! | 25.0 | 0.88 |
| condor_50 | P | 32 | 520 | 520 | 35 | 5/25 | 92 | 11 | 0 | 3.60/4.60 | 0.5-1.5 | 1.00+S | 227 | 1/0.00s | 2/1.71s | 2/1.71s | 21/45.83s | 47/104.83s! | 25.0 | 1.00 |

### special

| weapon | slot | lvl | dmg (pellet) | dmg@20m | rpm | mag/total | acc | stab | conc | reload t/e | pickup | AP(+S shield) | DPS | Heavy head | Heavy flank body | Heavy front body | Wrecker head | Wrecker body | ammo/kill | pickup/kill |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| rotor_saw | S | 14 | 30 | 0 | 600 | 150/300 | 42 | 99 | 18 | 3.80/3.80 | 5.0-10.0 | 0.00 | 241 | 22/2.10s | 22/2.10s | 22/2.10s | 800/98.40s! | 800/98.40s! | 13.6 | 0.34 |
| vise_crossbow | P | 23 | 350 | 350 | 50 | 1/25 | 97 | 97 | 22 | 1.60/1.60 | 0.5-1.0 | 1.00 | 219 | 1/0.00s | 2/1.60s | 2/1.60s | 30/46.40s! | 69/108.80s! | 25.0 | 0.75 |
| thorn_bow | P | 25 | 400 | 400 | 60 | 1/30 | 96 | 84 | 26 | 0.80/0.80 | 0.5-1.0 | 1.00 | 400 | 1/0.00s | 2/1.00s | 2/1.00s | 26/25.00s | 60/59.00s! | 30.0 | 0.75 |
| thumper_40 | P | 38 | 1000 | 1000 | 60 | 1/6 | 96 | 84 | 16 | 3.00/3.00 | 0.2-0.4 | 0.00 | 333 | 1/0.00s | 1/0.00s | 1/0.00s | 22/63.00s! | 22/63.00s! | 6.0 | 0.30 |
| furnace_ft | P | 40 | 20 | 0 | 600 | 300/600 | 17 | 100 | 5 | 6.00/7.00 | 12.0-25.0 | 0.00 | 178 | 32/3.10s | 32/3.10s | 32/3.10s | 1200/140.60s! | 1200/140.60s! | 18.8 | 0.58 |
| cyclone_rotary | P | 45 | 28 | 28 | 1500 | 500/1000 | 31 | 98 | 0 | 8.00/9.00 | 15.0-30.0 | 0.00 | 483 | 8/0.28s | 23/0.88s | blocked | 355/14.16s | 858/43.24s | 125.0 | 2.81 |

## Mechanical flags (tool output)

- NEAR-DOMINATED: hush_9 (lvl 15) beats hornet_9 (lvl 4) only in stab
- NEAR-DOMINATED: tern_556 (lvl 12) beats corsair_ar (lvl 3) only in conc
- SECONDARY-DPS: marshal_357 (pistol) sustained DPS 281 > the weakest AR (253)
- SNIPER-PER-SHOT: osprey_762 160 per shot vs the AR maximum 150
- PICKUP-FLOOR: condor_50 pickup min 0.5 < 1 (AmmoPickupSystem floors every box at 1 round)
- PICKUP-FLOOR: vise_crossbow pickup min 0.5 < 1 (AmmoPickupSystem floors every box at 1 round)
- PICKUP-FLOOR: thorn_bow pickup min 0.5 < 1 (AmmoPickupSystem floors every box at 1 round)
- PICKUP-FLOOR: thumper_40 pickup min 0.2 < 1 (AmmoPickupSystem floors every box at 1 round)
- WRECKER: cyclone_rotary kills a Wrecker in 14.2 s (355 of 1000 rounds)

## Outliers vs PD2 shapes (judgement)

1. **Tern 556 (AR, lvl 12) is a worse Corsair (lvl 3).** Both have the same spread, recoil, mag, reserve and pickup. The Tern
   does less damage (52 vs 55), fires slower (680 vs 700 rpm) and reloads slower (2.8/3.6 vs 2.4/3.1). Its only edge is
   +1 concealment, and it costs 6000 more. Tern DPS is 253 vs 295, with 5 vs 4 headshots on a Heavy. In PD2 a later
   mid-tier AR trades something real.
2. **Bastion BR (AR, lvl 24) gains nothing from its per-shot damage.** At 100 damage it needs 3 headshots on a Cataclysm
   Heavy, the same as the Drover 762 (80, lvl 9). The Drover beats it in rpm, mag, reserve, concealment, DPS (381 vs 359),
   pickup and reload. A PD2 heavy AR pays in ammo and concealment to reach a breakpoint, and the Bastion pays without reaching one.
3. **Falchion DMR (AR, lvl 20) leads the AR class in damage (150), DPS (483), accuracy (84) and Wrecker TTK (19.5 s).**
   Its DPS ties the rotary for the highest in the game and beats every LMG (max 379). It also overlaps the snipers: the
   Osprey 762 does 160 per shot (SNIPER-PER-SHOT flag) at 212 DPS. PD2 shape: snipers own per-shot damage, and ARs
   should not out-DPS LMGs by 25%.
4. **Marshal .357 (pistol, secondary) out-DPSes every SMG (281 vs at most 248) and two ARs (253).** A revolver should have
   the top per-shot damage among pistols, but a 6-round cylinder and a slow reload should keep its sustained DPS down.
   At 330 rpm with a 2.4 s reload, it doesn't.
5. **Wren .380 (lvl 2) is nearly dominated by the level-0 default Kestrel P9.** The Kestrel has more damage, mag (17 vs 7),
   reserve (153 vs 98), pickup and DPS (145 vs 78) at the same accuracy, stability and concealment 30. The Wren wins only
   in rpm and a 0.1 s faster reload. PD2 shape: a small-calibre pocket pistol trades damage for a big reserve and fast handling.
6. **Hush 9 (SMG, lvl 15) beats the Hornet 9 (lvl 4) only in stability** (flag). The Hornet has more damage, rpm,
   concealment (24 vs 21), DPS and a faster reload. The Hush's integral suppressor is real value, but in PD2 a suppressor
   adds concealment rather than taking it away, and the Hush has the lowest concealment of all SMGs.
7. **Vise Crossbow (lvl 23) is worse than the Thorn Bow (lvl 25) in every combat column except accuracy (+1) and
   stability.** It has less damage (350 vs 400), fewer bolts (25 vs 30), lower concealment (22 vs 26), a slower cycle (1.6 vs
   1.0 s) and less DPS (219 vs 400). PD2 shape: a crossbow is the heavy, slow, single bolt and should hit harder per shot than a bow.
8. **Warden .45 Pair (akimbo, PRIMARY, lvl 16) is a weak primary.** Its DPS of 170 sits below every primary AR, SMG-level,
   and its reserve of 128 is under the 2x single Warden (144) PD2 uses for akimbos. Concealment 23 is good, so this is
   a niche pick and not broken.
9. **The Cyclone rotary (lvl 45) is the only weapon that kills a Cataclysm Wrecker through body fire within its reserve**
   (858 of 1000 rounds). It also kills one in 14.2 s by the head route and has the best pickup/kill in the game (2.81,
   against 2.25-2.40 for LMGs). Being the last unlock makes it a dozer-killer by design (PD2 minigun shape), but its
   ammo economy shouldn't beat the LMGs, whose identity that is.
10. **Thumper 40 pickup**: the data says 0.2-0.4, but the pickup floor makes it 1 grenade per box (the PD2 launcher shape is
    a rare refill). This is an ENV A rule, not weapon data. See the cross-env list below.
11. **Checks that came back in shape**: no shotgun keeps more than 33% of its damage at 20 m. LMGs have the best ammo
    economy outside specials (60-62.5 kills per reserve, against 40 at most elsewhere). Concealment trades against damage
    inside every class except the Tern/Corsair pair. No level-0 to 5 weapon is best-in-class in every column. No special
    trivializes Wreckers (fastest 14 s, and the Thumper needs 22 of its 6 rounds). Secondaries (SMG max 248 DPS) sit
    just under the weakest primaries (253), which matches the PD2 secondary-vs-primary shape. Snipers are the only
    AP + shield-pierce class, and the Heron 308 and Condor 50 one-shot a Cataclysm Heavy on the head.
12. **Shotgun breakpoints (optional)**: at Cataclysm every shotgun needs 2 headshots on a Heavy even with all 10 pellets on
    the head. The Reaper DB (2 shells, highest per shot) gets no breakpoint for its 2-round mag.

### Cross-env observations (ENV A data or rules; the LEAD decides, and nothing here is a B change)

* **Wrecker HP vs player damage**: only 8 of 36 stock weapons can kill one Cataclysm Wrecker (24000 HP) solo within
  their full reserve: Falchion, Bastion, the three LMGs, Condor, Thorn Bow and Cyclone. A Corsair needs 181 rounds out of 150.
  The Wrecker scales x12 from Routine to Cataclysm while the Heavy scales x4, so the Wrecker:Heavy HP ratio goes from
  12.5 to 37.5. Please confirm with ENV A that this is intended. In PD2 shape a top-difficulty dozer is a crew-wide
  "focus it" target, not one that most stock primaries cannot finish with their whole reserve.
* **Pickup floor** (`AmmoPickupSystem`: `maxi(round(n), 1)`): a fractional pickup (launchers 0.2-0.4, bows and crossbow
  0.5-1.0) can never go below 1 per box. PD2 carries fractional pickups over. As things stand, the only data-side way to
  get a rarer refill is max = 0, which disables pickup.
* **TAC Heavy frontal plate x0**: every non-AP bullet body hit from the front does 0. This matches PD2's heavy chest
  plate. It makes headshots (or AP, fire, saw, explosives) mandatory on Heavies, and the TTK tables show it ("blocked").

## Proposed data-only fixes (for approval; NOT applied)

| # | file (base stat) | before -> after | derived effect | reason |
|---|---|---|---|---|
| P1 | `tern_556.tres` concealment, spread_deg_ads | 21 -> 24, 2.7 -> 2.1 | accuracy 44 -> 56 | gives the bullpup an identity (accurate and concealable) that pays for its lower damage, rpm and slower reload compared with the Corsair |
| P2 | `bastion_br.tres` damage | 100 -> 110 | Heavy head 3 -> 2 shots (660 >= 640); DPS 359 -> 395 | a heavy AR must reach the breakpoint it pays reserve and concealment for |
| P3 | `falchion_dmr.tres` damage | 150 -> 120 | DPS 483 -> 386; Heavy head stays 2; sniper floor (160) now above every AR | DMR stays the precise AR, snipers keep per-shot damage, and no AR out-DPSes the LMGs by 25% |
| P4 | `marshal_357.tres` fire_rate_rpm, reload_time_s / reload_empty_time_s | 330 -> 270, 2.4/2.4 -> 3.0/3.0 | DPS 281 -> 226 (below every AR, near the SMGs); 2 Heavy headshots unchanged | revolver = top per-shot damage among pistols, paid for in cadence and cylinder reload |
| P5 | `wren_380.tres` mag_size, total_ammo, fire_rate_rpm | 7 -> 10, 98 -> 160, 520 -> 600 | DPS 78 -> 103; reserve now above the Kestrel's 153 | pocket pistol = big reserve and fast handling, no longer a worse Kestrel |
| P6 | `hush_9.tres` concealment | 21 -> 25 | | PD2-shape suppressed SMG: concealable stealth pick, not the least concealable SMG |
| P7 | `vise_crossbow.tres` damage | 350 -> 450 | DPS 219 -> 281; Wrecker head 30 -> 24 bolts | crossbow = heaviest single bolt, paying with cycle and concealment against the bow |
| P8 | `akimbo_warden_45.tres` total_ammo | 128 -> 144 | ammo/kill 32 -> 36 | akimbo = 2x the single pistol's mag and reserve (PD2 shape) |
| P9 | `cyclone_rotary.tres` ammo_pickup_min / max | 15 / 30 -> 10 / 20 | pickup/kill 2.81 -> 1.88 (below the LMGs' 2.25-2.40) | LMGs keep the best ammo economy; the minigun's 1000-round reserve is its identity |
| P10 (optional) | `reaper_db.tres` damage (per pellet) | 19 -> 22 | 190 -> 220 per shot; Heavy head 2 -> 1 (660 >= 640); DPS 146 -> 169 | the 2-shell double barrel gets the one-shot breakpoint the other shotguns lack |

After approval, apply these as one commit and rerun the tool to confirm that the flags (NEAR-DOMINATED Tern and Hush,
SECONDARY-DPS Marshal, SNIPER-PER-SHOT Osprey) clear. Golden tests in `game/tests/b/` that pin these stats will need updating.

## Not determined

* The real bow and crossbow cycle (how CrewWeapons combines draw time, rpm and the reload of a 1-round mag). DPS assumes `max(60/rpm, reload)`.
* The rotary's spin-up, and whether flame ticks run at fire_rate_rpm (assumed yes). Burn DoT is assumed to refresh, not stack.
* Hit rate, falloff and range-dependent TTK: only point blank and the 20 m damage column are reported.
* Skills, perk decks and crits (D-027) are left out. The Cataclysm Wrecker numbers are solo; a 4-crew shares the load.
