# CAPERWORKS: game overview

*Working title "CAPERWORKS". All names in this document are original placeholders; the product
owner may rename. Mechanics replicate Payday 2; names, characters, and trademarks do not.*

## 1. Pitch

A first-person co-op heist shooter for 1–4 players. You plan a job, walk in unmasked, case the place,
and then decide **how loud the day gets**. Every heist can go from silent to all-out war at any
moment with no load and no reset. Everything you set up stays where it is: open doors, bagged
bodies, running drills. Solo is first-class. AI crew members fill the empty slots and follow orders.

## 2. Pillars

1. **Stealth is a game of rules, not realism.** Arcade stealth with the same readable,
   exploitable rules as PD2: no footstep noise, per-observer detection meters, four pagers,
   body bags, cable ties, and ECMs. Mastery comes from knowing the rules.
2. **Loud is a siege with a director.** Assault waves breathe (build, sustain, fade). Specials
   are puzzles with audio telegraphs. Pressure escalates over time.
3. **Builds change how you play.** Skills and perk decks unlock new verbs: dominate guards,
   inspire from range, ECM feedback, delayed-damage tanking, dodge chains. They are not just +5%.
4. **No two runs are the same.** Per-run variables change routes, decisions, and risk.
5. **Places feel real.** Buildings that make sense, dressed with care, readable at a glance.

## 3. Core loop

```
Hub (safehouse) ─► Job Board (contacts offer heists + difficulty) ─► Briefing & Pre-planning
   ▲                                                                       │
   │                                                              Heist: casing ─► stealth ─┐
   │                                                                     (alarm at any time) ▼
Results / Payday ◄── escape ◄── secure loot ◄─────────────────────────────── loud ◄─────────┘
   │
   └─► spend cash (armory, mods, masks, assets) / XP ─► levels ─► skill points / perk points
```

## 4. Cast (original)

| Role | Name | Function (PD2 analog) |
|---|---|---|
| Handler on comms | **Mercer** | Dry, calm voice on the radio; objective callouts (Bain) |
| Contact: fence | **Odile Vance** | Jewelry/art jobs; elegant, impatient |
| Contact: fixer | **Hollis "Hammer" Reyes** | Loud jobs, armored trucks, warehouses |
| Contact: insider | **The Accountant** | Bank/corporate/stealth-only data jobs; never seen |
| Crew (playable) | **Rook, Sable, Dutch, Wren** | Four voiced heisters (text/synth voice lines) |

## 5. Enemy roster (original names, PD2-faithful behavior; see `pd2_fidelity.md` §L)

| Our name | PD2 analog | Faction tier |
|---|---|---|
| Security Officer | Guard | stealth |
| Camera Operator | Security room guard | stealth |
| Patrol Officer | Beat cop | loud, first responders |
| TAC Light / TAC Heavy | SWAT / Heavy SWAT | loud |
| FRD Agent | FBI | loud, higher difficulty |
| **Phantom** | Cloaker | special |
| **Stinger** | Taser | special |
| **Bulwark** | Shield | special |
| **Wrecker** | Bulldozer | special |
| **Longshot** | Sniper | special |
| **Corpsman** | Medic | special |
| **Commander Brandt + Aegis squad** | Captain Winters + Phalanx | late-assault boss |

## 6. Progression names

* **Skill trees** (5 × 3 subtrees): **Ringleader** (Field Medic / Persuader / Marksman),
  **Bruiser** (Scattergun / Juggernaut / Quartermaster), **Wrench** (Sapper / Breacher / Gunnery),
  **Shade** (Infiltrator / Slipstream / Quiet Professional), **Outlaw** (Two-Gun / Undying / Scrapper).
* **Perk decks** (14): Foreman, Bulk, Ironclad, Slipper, Clean Sweep, Hustler, Prowler, Knuckles,
  Bloodletter, Composure, Overclock, Incumbent, Long Odds, Overlord. Full table in `pd2_fidelity.md` §P.
* **Difficulties** (6): Routine, Tense, Hazardous, Brutal, Lethal, Cataclysm.
* **Notoriety** (prestige, Infamy analog) after level 100.

## 7. Heist slate (each gets a design doc in `docs/design/heists/` before geometry)

| # | Id | Name | Archetype (PD2 analog) | Modes | Size | Phase |
|---|---|---|---|---|---|---|
| 1 | `glasshouse` | **Glasshouse**: Vossberg Jewelers | Jewelry Store | stealth + loud | S | **P1 vertical slice** |
| 2 | `night_deposit` | **Night Deposit**: Harbor Savings & Loan | Bank (small) | stealth + loud | M | P2 |
| 3 | `shadow_ledger` | **Shadow Ledger**: Kessler & Moor penthouse | Shadow Raid / data theft | **stealth-only** | M | P2 |
| 4 | `dockside_burn` | **Dockside Burn**: cartel cold-storage warehouse | Firestarter / Rats | **loud-only** | M | P3 |
| 5 | `gallery_night` | **Gallery Night**: Halberd Gallery | Framing Frame | stealth + loud | M | P5 |
| 6 | `meridian_federal` | **Meridian Federal** | Big Bank | stealth + loud | L | P5 |
| 7 | `rolling_thunder` | **Rolling Thunder**: armored convoy | Transport | loud (stealth-start ambush) | M | P5 |
| 8 | `afterhours` | **Afterhours**: the Velvet nightclub | Nightclub | stealth + loud | M | P5 |

## 8. Systems summary

* **Casing / masking**: unmasked casing mode, irreversible mask-up.
* **Stealth**: per-observer detection, guards with randomized patrols, pagers (4 max), body bags,
  civilians (intimidate, tie, re-shout), cameras + operator, ECM jammers, interactions with timers,
  drills that jam, keycards and codes, lasers, breakable glass.
* **Loud**: assault director (anticipation → build → sustain → fade → control), escalation,
  specials, downed / bleed-out / custody / hostage trade, armor/health/dodge, suppression.
* **AI crew** for solo: follow, revive, fight, carry bags when ordered, hold position.
* **Loot**: carried bags with weight classes, throwing, secure zones; payout scales with loot.
* **Armory and workshop**: 7 weapon classes + melee, throwables, deployables. Mods trade
  stats, especially concealment against performance.
* **Firing range**: test any loadout, distance markers, moving targets, armored special dummies,
  live stats, instant loadout swap.
* **Hub**: safehouse with job board, pre-planning table, armory, mask bench, firing range door.
* **Results**: payday screen with loot breakdown, stealth bonus, civilian penalty, XP, payday card.
* **Music**: phase-reactive loud tracks (stems: calm/stealth tension, anticipation riser,
  assault full, fade), synthesized in-house.

## 9. Out of scope (until the product owner says otherwise)

PvP. Microtransactions or loot-box monetisation; payday cards give cosmetics/mods earned in game only.
Online matchmaking service (direct IP / LAN plus Steam-less lobby codes first). VR.
