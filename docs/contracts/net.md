# Contract: networking (v1.1)

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
