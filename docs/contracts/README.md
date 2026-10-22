# Contracts index

Owner: **LEAD**. Only the lead edits contracts. Each file has a version. A breaking change bumps the
major version and comes with a `docs/decisions.md` entry and a migration note to the affected envs.

| Contract | Version | Producer → Consumer | Code |
|---|---|---|---|
| [heist_map.md](heist_map.md) | 1.4 | C → A (and B for UI) | `game/contracts/map/*`, `HeistDef`, `HeistVariantTable` |
| [gameplay_prefabs.md](gameplay_prefabs.md) | 1.5 | A → C (C places A's prefabs in maps) | `game/systems/prefabs/**` |
| [visual_slots.md](visual_slots.md) | 1.5 | C/B → A (art that plugs into prefabs) | — |
| [characters.md](characters.md) | 1.37 | C → A (rigs, animation names) | — |
| [events.md](events.md) | 1.9 | all ↔ all | `game/core/event_bus.gd` |
| [modifiers.md](modifiers.md) | 1.1 | B → A | `game/core/modifiers.gd`, `game/contracts/modifier_keys.gd` |
| [data_schemas.md](data_schemas.md) | 1.4 | B (data) → A (runtime) | `game/contracts/data/*` |
| [crew_intent.md](crew_intent.md) | 1.1 | A, LEAD tests | `game/contracts/crew_intent.gd` |
| [audio_cues.md](audio_cues.md) | 1.9 | C (sounds) ← A/B (triggers) | `game/world/audio/cues.tres` (C) |
| [preplanning.md](preplanning.md) | 1.2 | B (resolve, UI) / C (points, overrides) → A (apply) | — |
| [damage.md](damage.md) | 1.3 | A ↔ B (hits, targets) | `game/contracts/damage.gd` |
| [ui_hud.md](ui_hud.md) | 1.19 | A (state) → B (HUD widgets) | — |
| [groups.md](groups.md) | 1.2 | all | `game/contracts/ids.gd` (`G`) |
| [net.md](net.md) | 1.5 | LEAD → A, B | `game/core/net.gd` |
| [hub_map.md](hub_map.md) | 1.2 | C/A → B (safehouse hub) | `SafehouseMap`, `hub_station` |
| [impact_fx.md](impact_fx.md) | 1.1 | C (VFX, surfaces) ← A (shot events, doors), P (FP weapon), B (option) | `game/world/vfx/` |
| [input_focus.md](input_focus.md) | 1.2 | P → B, A (mouse capture, input focus) | `game/systems/player/mouse_capture.gd` |

Rules shared by all contracts:
* Producers ship **placeholders** first so consumers are never blocked (capsule NPCs, box props,
  beep sounds, grey UI). Placeholders must satisfy the contract shape exactly.
* Consumers must fail **loudly** (Log.error + test failure) on contract violations, never silently
  patch around them.
* Any "it would be easier if the other env just..." goes to the lead as a question.
