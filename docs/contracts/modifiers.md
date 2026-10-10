# Contract: modifiers (v1.0)

Skills, perk cards, pre-planning assets, difficulty and mutators affect gameplay **only** through
modifier keys. This is how PD2's `upgrade_value` system works, and it keeps ENV B (data) and ENV A
(behaviour) decoupled.

* Registry: `game/contracts/modifier_keys.gd` (`ModifierKeys.KEYS`), lead-owned. Each key has a type
  (MULT/ADD/FLAG/PARAMS), the phase it must work from, and a description.
* Service: `Modifiers` autoload (`game/core/modifiers.gd`). API documented in its header.
* **ENV B** resolves each crew member's skills and perk deck into `Loadout.modifiers` (key → value)
  and, at heist start on the server, calls `Modifiers.set_source(slot, &"skills", ...)` and
  `Modifiers.set_source(slot, &"perk", ...)`. Pre-planning assets use
  `Modifiers.set_source(Modifiers.TEAM, &"asset.<id>", ...)`.
* **ENV A** queries modifiers at the hook points. For every registry key with `phase <= current
  phase`, ENV A must have a test proving that the key changes behaviour.
* Qualified keys (`weapon.damage_mult.shotgun`): grant with a class qualifier or `.all`; query with
  `Modifiers.mult(slot, &"weapon.damage_mult", Enums.weapon_class_qualifier(cls))`.
* PARAMS keys carry dictionaries for perk-deck signature mechanics, e.g.
  `perk.stoic = {"dot_duration": 8.0, "flask_cooldown": 20.0, "auto_flask_after_s": 4.0}`.
  The param schema for each PARAMS key is documented by ENV A in `game/systems/modifiers_params.md`
  when it implements the key, and reviewed by the lead.
* Team-skill non-stacking (PD2 rule): crew-wide keys (`team.*`) from the **same skill id** held by
  multiple players are granted once. ENV B grants team keys with source `&"team_skill.<skill_id>"`
  on TEAM, which naturally deduplicates.
* New keys: request via your status file. Only the lead adds keys.
* CI: `game/tests/b/test_modifier_grants.gd` (ENV B, P2) asserts that every grant in content data is a known key.
