# Contract: networking (v1.0)

API: `game/core/net.gd`. Architecture: architecture.md §3.

* `Net.start_solo(name, ai)` / `Net.host(port)` / `Net.join(addr, port)` / `Net.leave()`.
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
