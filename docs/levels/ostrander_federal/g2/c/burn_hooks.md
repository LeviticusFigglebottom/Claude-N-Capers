# Ostrander Federal: burn-through and drill-drop hooks (OF-C2 lane C)

The set piece and the two drill-drop vehicles are presentation only. They are built **hidden** by
`game/world/heists/ostrander_federal/greybox/of_burn.gd`, under the lane-C art root `Props/DressC`. They have no
collider, no nav obstruction and no gameplay role. ENV A's mission (OF-A6) plays them. The lid (the replicated
prefab `Gameplay/Devices/Lid`, with children `Plug` and `Visual/LidPanel`), the hole's permanent nav carve, the `Hoist`
and the `RopeLadder` are not touched here, and nothing of this lane sits under `Gameplay/Devices/Lid`. At the burn the
mission calls `set_enabled(false)` on the lid, then plays the matching animation below.

| Node | When | Call | What it does |
|---|---|---|---|
| `Props/DressC/BurnThrough` | the drill finishes (`device_finished` on `LidDrill`) | `$BurnAnim.play(&"burn")` | Shows the root. Over 0.8 s the fallen lid's cracked marble plates and the concrete rubble drop from the hole to the vault floor and settle; they stay off the ladder foot (24, 13.6) and the hoist car (24, 15.2). Dust bursts below the hole at 0.75 s and puffs over it in TW at 0 s; a haze lingers until 59 s. The hole edge is scorched, with a molten rim, and its ember glow (`HoleEdge/EmberGlow`) cools from 3.0 to 0.5 over 20 s. 60 s long. |
| | late join / state restore | `$BurnAnim.play(&"burnt")` | The end state at once: debris at rest, glow 0.5, no dust. |
| `Props/DressC/DrillDropHeli` | `drill_delivery = drop_terrace`, when the drop is called | `$DropAnim.play(&"drop")` | Mercer's bird (`veh_heli_escape`) flies in from the south, hovers 13 m over the crate spot (20, 8.6, 33) from 6 s to 12 s, then leaves to the north-east and hides itself at 20 s. Spawn the crate (the drill bags) during the hover. |
| `Props/DressC/DrillDropVan` | `drill_delivery = drop_dock` | `$DropAnim.play(&"arrive")` | The second van (`veh_van_secure`) reverses in along Ledger Lane from the east and parks nose north, with its rear at the drop marker (14, 0, -4), in 6 s. |
| | late join | `$DropAnim.play(&"parked")` | Parked at once. |

Every root carries meta `fx_hook` (the call) and meta `lc_ignore`. They are FX and cosmetic vehicles, so levelcheck
skips them (the heli hovers by design). The AnimationPlayers' root is their parent, so the first key of each
animation sets `.:visible = true`.

Review: `game/world/tools/capture/of_burn_variant.gd` writes a test-only copy of the map in the burnt state, with the
lid prefab hidden (`--drops` also places the heli mid-hover and the van parked). Then render it with
`tools/levelcheck/render_shots.sh ostrander_federal g2 --scene=user://of_burn_test.tscn --out=... --cameras=rc_vault_hole`.
The shipped scene keeps everything hidden.
