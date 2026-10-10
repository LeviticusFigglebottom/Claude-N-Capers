# Contract: test hooks for integration gates (v1.1)

Producer: **ENV A** (P1). Consumer: **LEAD** integration tests (`game/tests/integration/`) and
ENV C's walkthrough bot. These APIs exist in shipping code (not test-only builds) but are inert
unless called.

```gdscript
class_name HeistLauncher  # game/systems/heist/heist_launcher.gd
## Load a heist into `parent` (or the scene tree root if null), solo session, fixed seed.
## Returns the HeistRuntime once the map is ready (variants resolved, NPCs spawned, crew spawned).
static func launch(heist_id: StringName, seed: int, difficulty: Enums.Difficulty,
		parent: Node = null, options: Dictionary = {}) -> HeistRuntime   # await-able (coroutine)
## options: { "ai_teammates": int (default 3), "loadouts": {slot: Loadout}, "skip_casing": bool,
##            "preplan": PreplanResult (preplanning.md), "is_pro": bool (pro job: no restarts; informational, ENV B) }

class_name HeistRuntime   # game/systems/heist/heist_runtime.gd (Node)
var map: HeistMap
var phase: Enums.HeistPhase
var variants: Dictionary            # resolved, see heist_map.md §5
var run_seed: int
func crew_controller(slot: int) -> Node        # the CrewController (CharacterBody3D)
func set_bot_intent(slot: int, intent: CrewIntent) -> void   # held: applied every physics tick until replaced/cleared
func clear_bot_intent(slot: int) -> void
func teleport_crew(slot: int, xform: Transform3D) -> void    # authority only
func npcs(role: StringName = &"") -> Array[Node]             # role: &"guard", &"civilian", &"police", &"special"...
func find_by_tag(objective_tag: StringName) -> Array[Node]   # gameplay prefabs by objective_tag
func detection_value(observer: Node, slot: int) -> float
func isolate_npc(npc: Node) -> void                         # TEST ONLY: despawn every other NPC (QA-9, D-032)
func teardown() -> void                                      # frees everything, Services.clear(), Ids.reset()
```

Bots aim by setting `look_yaw/look_pitch` toward a target; helper `CrewIntent` construction lives in
`game/tests/integration/bots/bot_util.gd` (LEAD).
