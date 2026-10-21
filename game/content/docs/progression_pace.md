# Progression pace (XP) model and options for the PO

LEAD 2026-10-21 (PO question from B's OF payday e2e: one first OF clear takes a new player to level 9 / 21 / 29).
**Proposal only: no data changed.** Numbers come from `tests/b/tools/progression_pace.gd` (headless), which drives the
real `PayoutCalculator`, `HeistFreshness` (D-139), the stealth bank and `XpCurve` with the current data (trunk
e91fa3c0), then the option variants. Re-run it after any data change:
`/opt/godot/godot --headless --path game --script res://tests/b/tools/progression_pace.gd`.

## How XP works today

- **XP does not depend on the heist.** `base = 2000 + 250 x bags` (payout.tres), then x DifficultyDef.xp_mult
  (Routine 1, Tense 2, Hazardous 5, Brutal 10, Lethal 11.5, Cataclysm 14), +10% per surviving teammate (cap +30%),
  the banked stealth bonus of the previous stealth clear (x1.1-1.25), and D-139 freshness (repeats -, rotation +).
  The heist only matters through its bag count, so OF (6 bags) gives the most and GH / SL / GN (2) the least.
- **Curve:** levels 0-100, step XP `900 -> 1,000,000` with exponent 3.36, then x0.5 (`xp_curve.tres`): 11.6 M XP to
  level 100.
- Not modelled: payday-card XP, Low Profile / perk xp_mult, notoriety bonus, pro jobs, custody (all small or
  situational; they only make the pace faster).

## PD2 for comparison

- PD2 reputation: per-level cost from about 900 XP (0 -> 1) to 1,000,000 XP (99 -> 100), gentle early and steep late;
  a little over **23 M XP** to level 100 [1][2]. Our curve has the same endpoints at **half the scale (11.6 M)**.
- PD2 difficulty XP multipliers include Very Hard x6, OVERKILL x10, Mayhem x11.5, Death Wish x13, Death Sentence x14
  [1]; ours (5 / 10 / 11.5 / 14 on Hazardous / Brutal / Lethal / Cataclysm) follow that ladder.
- PD2 job XP grows with the job (more days / stages, more loot); ours is flat per heist (only bags). PD2's
  first-hour pace is also fast: the low levels are cheap by design.

## Current pace

First clear from a fresh profile (typical clear: the heist's required bags, stealth where allowed, crew of 4 alive):

| Difficulty | GH (2 bags) | ND (4) | SL (2) | DB (4, loud) | GN (2) | OF (6) |
|---|---|---|---|---|---|---|
| Routine | 3,250 XP, L7 | 3,900, L8 | 3,250, L7 | 3,900, L8 | 3,250, L7 | 4,550, L9 |
| Tense | 6,500, L12 | 7,800, L13 | 6,500, L12 | 7,800, L13 | 6,500, L12 | 9,100, L14 |
| Hazardous | 16,250, L19 | 19,500, L20 | 16,250, L19 | 19,500, L20 | 16,250, L19 | 22,750, L21 |
| Brutal | 32,500, L24 | 39,000, L25 | 32,500, L24 | 39,000, L25 | 32,500, L24 | 45,500, L26 |
| Lethal | 37,375, L25 | 44,850, L26 | 37,375, L25 | 44,850, L26 | 37,375, L25 | 52,325, L27 |
| Cataclysm | 45,500, L26 | 54,600, L27 | 45,500, L26 | 54,600, L27 | 45,500, L26 | 63,700, L29 |

New-player path (every heist once per difficulty, GH and ND first, then one difficulty up):

| After | Routine | Tense | Hazardous | Brutal | Lethal | Cataclysm |
|---|---|---|---|---|---|---|
| Level (36 clears total) | **21** | 29 | 38 | 46 | 51 | 56 |

Clears from level 0 to 100:

| Difficulty | Rotating all 6 heists | Grinding OF only (D-139 repeat penalty) |
|---|---|---|
| Routine | 3,097 | never (freshness floor) |
| Tense | 1,548 | never |
| Hazardous | 619 | 4,050 |
| Brutal | 310 | 2,004 |
| Lethal | 270 | 1,737 |
| Cataclysm | 221 | 1,419 |

**Read:** the curve is PD2-shaped. The jump the PO noticed is the cheap low end (6 Routine clears = level 21) plus the
big difficulty multipliers on a curve half as long as PD2's: one first Cataclysm clear lands at level 26-29. The top
end is long (221 Cataclysm clears). D-139 already makes grinding one heist ~6x slower than rotating.

## Options (proposals; the tables are from the same script)

### A: curve x4 (`xp_curve.scale` 0.5 -> 2.0; 46.6 M to level 100, twice PD2)

| | Routine | Tense | Hazardous | Brutal | Lethal | Cataclysm |
|---|---|---|---|---|---|---|
| First OF clear | L2 | L5 | L11 | L16 | L17 | L18 |
| New-player path, after | L11 | L19 | L26 | L32 | L37 | L40 |
| Clears to 100 (rotating) | >5,000 | >5,000 | 2,478 | 1,239 | 1,077 | 885 |

Slows the start (good) but makes the end four times longer: too long. A x2 curve (= PD2's 23 M) sits halfway: see D.

### B: flatter difficulty XP (xp_mult 1 / 1.5 / 2.25 / 3.25 / 4.25 / 5)

| | Routine | Tense | Hazardous | Brutal | Lethal | Cataclysm |
|---|---|---|---|---|---|---|
| First OF clear | L9 | L12 | L15 | L18 | L20 | L21 |
| New-player path, after | L21 | L28 | L33 | L38 | L42 | L45 |
| Clears to 100 (rotating) | 3,097 | 2,064 | 1,376 | 953 | 729 | 619 |

Removes the "one Cataclysm clear = level 29" jump and keeps Routine as is; but high difficulties pay far less XP than
PD2 (Cataclysm x5 vs PD2 x14), so the top end gets nearly 3x longer. Moves away from PD2 fidelity.

### C: heist-size base XP (S 1,500 / M 2,000 / L 2,500-3,000) + B's multipliers

| | Routine | Tense | Hazardous | Brutal | Lethal | Cataclysm |
|---|---|---|---|---|---|---|
| First OF clear | L11 | L14 | L17 | L20 | L22 | L23 |
| New-player path, after | L22 | L29 | L34 | L38 | L42 | L46 |
| Clears to 100 (rotating) | 2,860 | 1,907 | 1,271 | 880 | 673 | 572 |

Makes the big heists worth more XP than GH (PD2-like: bigger job, more XP) while keeping the start where it is.

### D: curve x2 (= PD2's 23.3 M) + C's heist-size base, PD2 difficulty multipliers kept

| | Routine | Tense | Hazardous | Brutal | Lethal | Cataclysm |
|---|---|---|---|---|---|---|
| First OF clear | L6 | L11 | L18 | L23 | L24 | L25 |
| First GH clear | L2 | L5 | L12 | L17 | L18 | L19 |
| New-player path, after | L17 | L25 | L32 | L39 | L44 | L49 |
| Clears to 100 (rotating) | >5,000 | 2,860 | 1,144 | 572 | 498 | 408 |

## Recommendation (B's view; the PO decides)

The pace is close to PD2's shape already; the outlier is how far one high-difficulty clear jumps a new player. The
lightest PD2-faithful fix is **D** (curve x2 = PD2's 23 M total, heist-size base XP, PD2 difficulty multipliers kept):
small heists stop paying as much as OF, a first OF clear lands at L6 (Routine) / L25 (Cataclysm) instead of L9 / L29,
six Routine clears give L17 instead of L21, and level 100 takes ~408 Cataclysm or ~572 Brutal clears (PD2-like, about
twice today). If the PO only minds the high-difficulty jump, **B** (flatter multipliers) fixes exactly that but moves
off PD2's multiplier ladder. B can produce any other mix in minutes with the script. Gate any change on the
level-locked unlocks (weapons, armor `unlock_level`, Bot Crew armors): their levels assume the current pace.

Sources:
[1] [Reputation (Payday 2), Payday Wiki](https://payday.fandom.com/wiki/Reputation_(Payday_2))
[2] [How do you become Infamous in Payday 2? (Cyberpost)](https://cyberpost.co/how-do-you-become-infamous-in-payday-2/)
