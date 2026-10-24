# Contract: networking (v1.6)

API: `game/core/net.gd`. Architecture: architecture.md §3.

* `Net.start_solo(name, ai)` / `Net.host(port, name)` / `Net.join(addr, port, name)` / `Net.leave()`. A client sends
  `name` to the host on connect (names its slot). Client signals `connected_to_host`, `connection_failed`, `host_lost`
  (the latter two also leave the session). host/join/leave never double-connect handlers (D-052).
* Crew registry `Net.crew[slot] = {peer_id, is_ai, display_name}`; AI peer_id = 0. Helpers:
  `all_slots()`, `human_slots()`, `local_slot()`, `slot_of_peer()`, `fill_with_ai()`.
* `Net.is_authority()` guards every state mutation.
* `Net.replicate_event(signal, args)` relays EventBus facts to clients.
* ENV A owns all gameplay replication (spawners, synchronizers, RPCs inside `systems/`). Lobby UI
  (ENV B) uses only the `Net` API.
* Every gameplay RPC: `@rpc("any_peer", "call_remote", "reliable"|"unreliable_ordered")` for client
  → server intents, with `multiplayer.get_remote_sender_id()` validated against the crew slot;
  `@rpc("authority", ...)` for server → clients.
* Integration test `tests/integration/test_coop_loopback.gd` (LEAD, P3) runs a host plus a client in
  one process via two `SceneMultiplayer` branches and asserts state parity.
* Late join (drop-in) mid-heist: P6. Until then, joining is lobby-only.

## Client heist launch (A3-07, D-054)
* `HeistLauncher.launch_client(parent = null, options = {}, timeout_s = 0.0) -> HeistRuntime` (await) on a client after
  `Net.join()` connected and before the host's `HeistLauncher.launch()`, at the latest in the lobby's "starting"
  message handler. It waits for the host's bring-up lobby message (`HeistLauncher.BRING_UP_KIND`, version
  `BRING_UP_VERSION`), builds the replica (`is_replica`, `heist_loaded` already emitted, `rt.hud_model` = the client's).
* Returns null (never throws) on the authority, a rejected bring-up, timeout, host lost / session ended, or
  `HeistLauncher.cancel_launch_client()`. Clients receive `heist_ended` [R]; the app flow then calls `rt.teardown()`
  and `Net.leave()`. Full details: game/systems/heist/README.md "Client heist launch".
* Bring-up (and drop-in `late_bring_up`) carries `"objectives"`: the host's `[id, state, data]` list at send time; the
  replica's HUD model seeds from it, because mission-start `objective_updated` [R] arrives before the replica exists
  (PO-B-C7). Additive key: `BRING_UP_VERSION` unchanged, older clients ignore it.
* C11 (round 100, A): a co-op session survives a heist. Bring-up carries a per-heist `"token"`; the host replicates only
  to its member set (peers at `begin()`, drop-ins after their late bring-up, minus leavers). Lobby kinds `heist_closed`
  (host → clients: the replica freezes, `HeistNetSync.host_closed` fires) and `heist_left` (client → host). `launch()` on
  a live session tears down any leftover runtime first. After teardown the host calls `Net.clear_ai()` (drops AI seats
  so newcomers can join). In the lobby, empty seats are filled with AI by design (`fill_with_ai()`), a leaver's seat
  becomes AI and a newcomer replaces an AI seat (`_on_peer_connected`); never call `clear_ai()` from a `crew_changed`
  handler (fill_with_ai re-emits it per seat and would loop).
* ENet peer timeout (lead, round 80): `Net` sets (32, 15 000 ms, 60 000 ms) on every peer, both sides, so a host's
  bring-up stall does not drop clients. A human slot falling back to AI is logged (`Log.warn`, channel `net`).

## v1.1: kick, lobby message kinds, drop-in policy (D-072)
* `Net.kick(peer_id) -> bool` (host only): disconnects the peer, frees its crew slot (an AI may fill it per lobby
  rules) and emits `peer_kicked(peer_id, slot)`. The kicked client receives `host_lost`-style teardown with
  `Net.last_disconnect_reason == &"kicked"`. Kicked peers are auto-denied for the rest of that lobby session
  (the host's kick list, keyed by peer id and lower-cased profile name); `Net.was_kicked(display_name) -> bool` queries it.
* Reserved `Net.lobby_send` kinds (ENV B): `lobby.chat` (text chat, lobby and in-heist; the sender slot comes from the
  network sender id, never the payload), `lobby.kick` (UI notice only; the kick itself is `Net.kick`), `lobby.settings`
  (host-only session settings, e.g. `{dropin}`). `lobby_message` delivery keeps working during and after a launch
  until `Net.leave()`. Other envs must not reuse `lobby.*` kinds.
* Drop-in (P6): host policy `ask` (default) / `auto` / `off`, as in PD2. ENV A implements ENV B's `DropInService`
  interface (group `G.DROP_IN_SERVICE`); joiners are validated with `LobbyState.validate_summary`.
  `answer_join(peer_id, accept, reason := &"denied")`; `join_failed` reasons: denied, timeout, full, cancelled,
  host_lost, kicked, off (plus ENV B's client-side `unreachable`: no reply from the host before any request). The policy is a host preference (persisted in GameSettings) copied into each new session.
* Lobby codes (ENV B): Crockford base32 + Luhn mod-32 over IPv4:port; IPv6 out of scope. No LAN discovery yet.

## D-105 presentation facts (HeistNetSync, RELIABLE)
`_rpc_crew_shot`, `_rpc_impact_fx`, `_rpc_explosion_fx`: see impact_fx.md 1.1 §2. Presentation only; gameplay stays server-authoritative (hit claims unchanged). Crew spread draws one GameRng `spread` seed per shot, then a per-shot RNG for pellets.

## v1.2 (PO6-19, D-114 §7): NPC ragdoll state keys
NPC entity state (`NetEntityCodec.state_of` / `_apply_npc_state`, reliable diffs; late joiners get the full state) gains
two keys, written by `NpcRagdoll.net_state(st)` on the server and applied by `NpcRagdoll.apply_net_state(d)` on clients
(`game/systems/anim/npc_ragdoll.gd`, env/a-core f16e1031). Both are present only once set; NPCs without ENV D's
`Skeleton3D/Ragdoll` (capsule placeholders) never carry them.
* **`"rs"` = `[seq: int, settle_s: float, entries: Array]`**: the latest ragdoll start or push fact. `seq` counts the
  server's starts/pushes for this NPC (strictly increasing); `settle_s` is the simulation time before the freeze;
  `entries` = `[[body_index: int, impulse: Vector3 (N·s, world space), offset: Vector3 (m, from the body's origin)], ...]`.
  `body_index` indexes the `PhysicalBone3D` children of `Skeleton3D/Ragdoll` in scene order (characters.md v1.12).
  A client applies an `rs` whose `seq` is newer than the last it applied: it starts (or nudges) its own ragdoll
  **cosmetically** with the same impulses. An empty `entries` = a start with no push (e.g. frozen by the cap first).
* **`"rp"` = `[seq: int, root_origin: Vector3, visual_offset: Vector3, bones: Array[Transform3D]]`**: the server's
  frozen pose, sent once per freeze. `root_origin` = the NPC root's global position after the server re-anchored it
  under the **hips** body; `visual_offset` = `visual_root.position` (the visual shifted back so the body stays put);
  `bones` = **12** baked bone transforms in skeleton space, one per ragdoll body, indexed like `body_index` (the
  12 bodies of characters.md v1.12: `Hips` … `ShinL/R`). A client snaps to an `rp` whose
  `seq` is newer than the last it applied; when `rp.seq >= rs.seq` (late joiner) it skips the simulation and only snaps.
  Clients never re-anchor on their own.
* While the ragdoll owns the pose, `NetEntityCodec.apply_xform` ignores the NPC's replicated root transform: the root
  comes from `rp`. Gameplay stays server-side (corpse stimulus, bag-body interaction and corpse hitbox follow the server's
  re-anchored root).

## v1.3: replicated NPC one-shot presentation clips (A 07faa63e)
* Cue `HeistNetSync._rpc_npc_oneshot(net_id: int, clip: StringName, start_s: float, speed: float)`: reliable,
  authority → clients, sent via `relay_npc_oneshot` under the same live-session check as the fx relays. The client plays
  the clip from `start_s` at `speed` until it ends (a missing clip plays nothing); no turn/snap cuts it. Carries
  `door_kick_<fam>` / `shield_bang` at breach start (re-sent if the host re-seeks a late kick) and `panic_start`.
* NPC state key `"ah"`: the brain's anim hint when it is in `AnimDriver.NET_HINTS` (today only `cuff`, a held loop), else
  `""`; reliable diffs, so late joiners get it.
* Still host-only presentation (acceptable, cosmetic): bulwark `shield_bang` outside a breach, `kick_charge`, `heal_ally`.

## v1.4 (OF-A2): generic prefab enable key
NetEntityCodec key `pe` (bool) on every GameplayPrefab: its enabled state (sent in snapshots for late joiners).

## v1.5 (OF-A6): generic prop `height_m`
NetEntityCodec carries `height_m` (float) on Ladder (and any prop exposing it) so late joiners get the runtime length.

## D-164: Copycat loadout fields
`Loadout.perk_choices` (card index -> option index) and `Loadout.perk_mimic_deck` ride with the loadout like
`perk_deck` / `perk_deck_cards` (LobbyState loadout data, the host's launch loadouts), so the server's
LoadoutResolver / ModifierPush resolves a Copycat crew member's chosen options and mimicked card the same on every peer.

## v1.6: Client snapshot interpolation and the remote-shooter claim window (D-170, P6)

**Interpolation (client, render-only).** `HeistNetSync` stamps every `_rpc_xforms` batch with its send tick (`SYNC_HZ` 15 Hz).
A client's `NetInterp` buffers each entity (live NPCs, loose bags, remote crew members) and renders it `NetInterp.DELAY_S`
(0.1 s, 1.5 send intervals) behind the newest server time it has heard of. It lerps between the two samples around that
time (Transform3D: position lerp + rotation slerp; crew: position, yaw the short way, pitch). Past the newest sample (a
lost or late packet) it extrapolates along the last segment for at most `EXTRAP_MAX_S` (0.15 s), then holds. A jump over
`SNAP_M` (3 m) snaps (teleport / warp). The playout clock advances with the frame and eases toward its target
(`CLOCK_EASE_S` 0.5 s; it snaps past `CLOCK_SNAP_S` 0.25 s), so arrival jitter doesn't jump render time. Never buffered: the
local crew member (client-predicted), corpses (anchor-owned), ragdolls and carried bags. Clients never simulate these
bodies, so authority and physics are unchanged (the host owns them).

**Claim window (server, gameplay).** Clients claim hits from their own view (A1-08). With interpolation that view is
`DELAY_S` + RTT/2 old, so a running target sits up to ~0.5–0.7 m from where the server has it now. That is past the head
tolerance (0.45 m) and sometimes the body tolerance (1.6 m). `NetRewind` (a child of the authority's `HeistNetSync`, live
sessions only) samples every NPC root position at the transform rate and keeps 0.6 s. For a **remote human shooter
only**, `CombatSystem`'s body-centre and head checks also accept a claim against any sampled position inside
`DELAY_S + RTT/2 + MARGIN_S` (0.1 s) of now, capped at 0.6 s (RTT from the shooter's ENet peer). Host shooters and AI crew
check against the present only. Every other claim check (origin, distance, rate of fire, LOS, pellets) is unchanged.

**Why.** PD2's feel is client-authoritative: a hit where you saw the enemy counts. Without the window, interpolation would
quietly turn a remote player's headshots on runners into body shots. The window is co-op PvE only and capped at 0.6 s of
past positions, which is generous but bounded; there is no PvP to exploit.

**Evidence.** a/test_p6_net_interp (sampling, extrapolation, snap, late chunks, the playout clock, non-buffered entities,
and the claim window for remote, host and AI shooters). A4-03 soak with `CAPER_SOAK_RELAY` (LossyRelay: latency, jitter,
loss) and `CAPER_SOAK_NO_INTERP`, MotionStats per client: frame pops > 0.25 m drop from ~180 to 0.2 per NPC-minute on
loopback and from ~275 to 0.6–0.8 at 120 ms / 5 % loss; jerks drop 94–96 %; 0 desync (env_a.md -66).
