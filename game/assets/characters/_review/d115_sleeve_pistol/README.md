# D-115 queue 1: heister FP sleeves / gloves under the one-handed pistol framing (D-116)

Tool: `game/world/characters/_tools/render_sleeve_pistol_review.tscn`. It runs the real viewmodel on the unit map with
the kestrel_p9, uses `FpViewmodel.apply_sleeves(<heister>)` for each of the 6 heisters, and captures hip and ADS
(settled). Rows: rook, sable, dutch, wren, marten, jay. Columns: hip, ADS.

| heister | sleeve variant applied | hip: cuff / seam visible | ADS: cuff / seam visible |
|---|---|---|---|
| rook | yes | no (wrist below frame) | no |
| sable | yes | no | no |
| dutch | yes | no | no |
| wren | yes | no | no |
| marten | yes | no | no |
| jay | yes | no | no |

- 16:9 (`sheet_16x9.png`) and 4:3 (`sheet_4x3.png`): only the glove and the gun are in frame. The wrist, cuff and
  sleeve stay below the bottom edge in every heister, hip and ADS. Nothing to fix.
- Note for the lead/P: with this framing a heister's pistol identity is the glove alone. rook and wren both wear
  black gloves, so they read identically with the pistol out.
