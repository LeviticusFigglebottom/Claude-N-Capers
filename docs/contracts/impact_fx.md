# Contract: combat & world effects (impact FX, tracers, muzzle flash, debris)

Version **1.1** (D-105; 1.1: door swing tunables, shot replication facts). Owner: LEAD. Producer of effects: ENV C (VFX library + surface tags). Triggers: ENV A (shots,
impacts, NPC/third-person weapons, doors), ENV P (first-person weapon). Consumers: every heist (all maps inherit it).

## Goal
Gunplay and world interaction must feel physical: every shot shows a muzzle flash and (for most weapons) a tracer, every
impact throws material-specific debris + a decal + a sound, and doors swing instead of snapping. All of it is procedural
(GPUParticles3D / meshes / shaders built by our scripts; no third-party assets), pooled, capped, and works for every peer.

## 1. Surface materials (ENV C tags, everyone reads)
Every collision body that bullets can hit carries a surface id: `metadata/surface` (StringName) on the CollisionObject3D,
or on a parent StaticBody3D/RigidBody3D/CharacterBody3D (walk up to 3 parents), else `&"concrete"`.
Ids: `concrete`, `brick`, `plaster`, `tile`, `wood`, `metal`, `glass`, `fabric`, `dirt`, `water`, `flesh`, `armor`,
`shield`. Characters/NPCs resolve to `flesh` (or `armor`/`shield` from the hit zone). C tags the kits/props/maps
(A keeps co-ownership of existing heists' files per D-104; C coordinates).
`ImpactFx.surface_of(collider: Object) -> StringName` (C) implements the lookup.

## 2. Event (ENV A)
`EventBus.shot_fx(origin: Vector3, end: Vector3, normal: Vector3, surface: StringName, weapon_class: StringName,
shooter_net_id: int, flags: int)`, **local presentation only**, emitted on EVERY peer for every hitscan ray/pellet
(crew and NPC): shots replicate through three RELIABLE [R] facts on HeistNetSync (1.1, env/a-core ec27e45c): `_rpc_crew_shot(crew_net_id, origin, dir, spread_deg, pellet_seed, weapon_slot)` (each peer replays the seeded pellets), `_rpc_impact_fx(shooter_id, from, to, target_id, mode)` (NPC shots, melee), `_rpc_explosion_fx(pos, radius, kind)`; each peer emits the local signals from them. `end` = impact point, or max range if nothing was hit (`normal` = ZERO,
`surface` = &""). `flags`: bit0 = suppressed, bit1 = first-person shooter on this peer (P draws its own muzzle/tracer
origin), bit2 = headshot, bit3 = penetrated. Melee impacts use the same event with `weapon_class = &"melee"`. Flag constants: `EventBus.SHOT_FX_SUPPRESSED/FIRST_PERSON/HEADSHOT/PENETRATED`. `weapon_class` = the WeaponDef class id (`ar`, `smg`, `lmg`, `pistol`, `shotgun`, `sniper`, `melee`; NPC weapons map to the nearest class).
Explosions: `EventBus.explosion_fx(pos, radius, kind)`.

## 3. Effects (ENV C library, `game/world/vfx/`)
- `ImpactFx` autoload-free static API listening to `shot_fx` / `explosion_fx` via a `VfxDirector` node the map/runtime adds:
  per surface: debris particles (chips/splinters/sparks/glass shards/dust/blood mist), a decal (pooled, cap 128 per map,
  fade after 60 s), an audio cue `cue.impact_<surface>` (audio_cues addition, C produces).
- `TracerFx`: a streak from muzzle to `end` (speed ~400 m/s visual, every Nth bullet per weapon class: AR/SMG/LMG 1 in 2,
  pistols/shotguns 1 in 3 per pellet group, snipers every shot), skipped when suppressed unless the weapon class says so.
- `MuzzleFx`: flash sprite/mesh burst + smoke puff + the light (P's 0.05 s light, D-094) for third-person weapons;
  suppressed = small puff, no flash.
- `ShellFx`: ejected casing (pooled, physics-lite), optional per weapon class.
- Budgets: ≤ 1.5 ms GPU on llvmpipe-equivalent at 720p in a loud firefight (A4-02 style probe), all pools capped;
  `Reduce Motion` / a `Graphics > Effects quality` option (B) scales counts down.

## 4. Who hooks what
| Piece | Owner |
|---|---|
| Surface ids on kits/props/maps, VFX library, impact/tracer/muzzle/shell scenes, impact audio cues | ENV C |
| `shot_fx` / `explosion_fx` emission on every peer; third-person muzzle anchors on crew/NPC weapon visuals; door swing animation | ENV A |
| First-person muzzle flash + tracer origin at the viewmodel `Muzzle`, shell ejection port, camera kick per shot | ENV P |
| Effects-quality option, impact cues mix check in Options | ENV B |

## 5. Doors (ENV A, door.gd)
Leaves animate open/closed over `InteractionTweak.door_swing_open_s` 0.35 / `door_swing_close_s` 0.45 / `door_swing_breach_s` 0.15 (0 = snap; ease-out), collision
follows the leaf (no snapping through the player; a leaf blocked by a body stops and the door stays "open" logically),
breach/kick opens faster (0.15 s); replicated state stays the authoritative open/closed bool, clients animate locally.
Door frames must close the gap to the wall: ENV C adds a validate_level check `door_frame_gap` (no visible gap > 2 cm
between frame, leaf and wall opening).

## Tests
A: shot_fx emitted on host and client for crew and NPC shots (loopback); door swing duration and blocked-leaf behaviour.
C: surface lookup on every kit piece; pools capped; a windowed capture sheet of every surface's impact.
P: windowed FP fire capture showing flash + tracer from the muzzle.
