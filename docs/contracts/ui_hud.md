# Contract: HUD data (v1.0)

ENV A exposes in-heist state. ENV B owns every UI scene, HUD included (one UI style, one owner).

* ENV A provides `LocalHudModel` (`game/systems/hud_model/local_hud_model.gd`, added under
  HeistRuntime on every peer) with typed properties and change signals for the **local** crew member:
  health/armor/max values, downs left, state (Enums.CrewState), bleedout timer, ammo (mag/reserve
  per slot), equipped slot, deployable/throwable counts, cable ties, body bags, carried bag
  (loot id, weight), interaction prompt (text key, progress 0..1, blocked reason), detection
  indicators (array of {observer_net_id, world_pos, value, kind}), marked targets, pager timers,
  ECM timer, camera countdown, objectives list, assault phase + wave, hostages count, Phantom/Stinger
  warnings, crew teammate panels (name, health, armor, state, downs, carried bag), casing/masked flag.
* ENV B builds `game/content/ui/hud/` scenes that bind **only** to `LocalHudModel` and EventBus.
* Text: all player-facing strings live in `game/content/data/strings/en.csv` (B), keys used by A for
  prompts (`ui.prompt.answer_pager`).
