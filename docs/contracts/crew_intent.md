# Contract: CrewIntent (v1.0)

`game/contracts/crew_intent.gd`. A single per-tick intent struct drives every crew member:

| Producer | Where |
|---|---|
| Local human input | ENV A `systems/player/player_input.gd` (the only place raw `Input` is read for gameplay) |
| AI teammate brain | ENV A `systems/ai/crew_ai/` |
| Integration-test bots | LEAD `game/tests/integration/bots/` |

* The human client sends its intent to the server at 30 Hz (unreliable-ordered RPC) and predicts
  its own movement. AI and bots produce intents on the server directly.
* `CrewController.apply_intent(intent: CrewIntent)` (ENV A) is the single entry point and is
  callable on the server for any crew slot. Tests use `HeistRuntime.crew_controller(slot)`.
* `interact_target_net_id` lets bots and AI target an interactable explicitly. Humans use aim (the
  server resolves the target with a 2 m ray plus a 10° assist cone).
* Orders (`order`, `order_target_net_id`, `order_position`) are issued by humans to AI teammates.
  Valid orders: `&"follow"`, `&"hold"`, `&"carry_bag"`, `&"drop_bag"`, `&"revive"`.
