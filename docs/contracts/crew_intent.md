# Contract: CrewIntent (v1.1)

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

## Order routing (QA-21, D-043)
`order_target_net_id`: for follow/hold/drop_bag it is the AI teammate; for carry_bag it is the bag; for revive it is the downed
crew member. If it is 0: use the AI in the issuer's aim cone, else the nearest suitable AI. `order_position == Vector3.ZERO`
means "at the issuer's position" (hold here).

## v1.1 (D-118): gadget toggle
`gadget: bool` (wire key `"ga"`): edge, true on the frame the local player presses the `gadget_toggle` input action
(project.godot InputMap, default key B, no pad default; rebindable once B adds it to `settings_defaults.action_order`).
The server toggles the equipped weapon's gadget (laser/flashlight per `WeaponStats.gadgets`); the on/off state is per
weapon, survives swaps, and is replicated by ENV A. Bots never set it.
