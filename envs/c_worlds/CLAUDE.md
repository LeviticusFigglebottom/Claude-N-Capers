# ENV C: Worlds & Art

You are **ENV C**, one of three implementation sessions. The lead session
(`session_01FCtEudjuevi6MHipm4R11R`) is your only point of contact. You do not talk to ENV A or ENV B.

## Scope (you own)
`game/world/**`, `game/assets/**` (except `assets/weapons/`), `tools/blender/**` (except
`weapons/`), `tools/texgen/**`, `tools/audiogen/**`, `tools/levelcheck/**`, `docs/levels/**`,
`docs/design/heists/**` (drafts; the lead approves), `game/tests/c/**`, `docs/status/env_c.md`.
That covers: the asset pipeline (Blender-via-Python library used by you AND ENV B), procedural
textures, materials, shaders, VFX, lighting, characters and animations, all audio (SFX, music,
voice synthesis) plus the runtime players for music/ambience/cues, every heist map including its
dynamic-variable hooks (VariantSlots, variant tables, patrol graphs, spawn/tactical points, zones,
rooms, mission scripts), `validate_level`, and review screenshots.

## You must NOT touch
`game/core/**`, `game/contracts/**`, `project.godot`, `docs/**` except your files listed above,
`tools/ci/**`, `game/systems/**` (ENV A; you *instance* A's prefabs in maps, you never edit them),
`game/content/**`, `game/assets/weapons/**`, and `tools/blender/weapons/**` (ENV B).

## Highest-risk area: levels
`docs/design/level_standards.md` is binding. In short:
- **G0:** the design doc (template §9) is approved by the lead **before any geometry**.
- **G1:** greybox, then validate, then walkthrough bot, then lead review. **G2:** art pass, then
  validate (final), then screenshots, then lead review.
- Nothing floats, nothing clips, nothing is half-done, no default material, every light has a
  fixture, and buildings make architectural sense. **Your `validate_level` must catch these
  programmatically.** Fix problems by placement, never by hiding.

## Contracts (read before coding)
- `docs/architecture.md`, `docs/art/style_guide.md` (you implement it), `docs/design/level_standards.md`
- `docs/contracts/`: heist_map (you produce), gameplay_prefabs + visual_slots (you supply visuals
  with exact node names), characters (you produce), audio_cues (you produce), groups, events (music
  and audio listen to them).
- `docs/design/pd2_fidelity.md` for what levels must support (variables, stealth routes, police entries, sniper perches).
- `docs/roadmap.md`: your tasks are `C<phase>-<nn>`.

## How to work
- Work **subagentically**: parallel Agent subtasks (pipeline lib, texgen, audiogen, characters,
  map greybox, validator), then integrate and verify them yourself.
- **Every asset is reproducible**: script in `tools/`, output in `game/assets/...` with `SOURCE.txt`.
  Deterministic seeds. Never hand-edit outputs.
- Blender: `bash tools/setup/install_blender.sh` (pinned 4.5 LTS), run headless `blender -b --python ...`.
- Rendering screenshots in a headless container: try `--rendering-driver opengl3` with xvfb
  (`xvfb-run`) or a lavapipe/llvmpipe software Vulkan. Report what works in your status (first
  P1 question for the lead if nothing works).
- Art direction is provisional (D-012). Keep pipeline and materials parametric so a direction
  change is a parameter change, not a rewrite.

## Session loop
1. `git fetch origin && git merge origin/claude/dreamy-hamilton-pc7vck` (merge, don't rebase).
2. Read new `docs/decisions.md` entries and your latest task message from the lead.
3. Work. Commit small (`[C1-04] floating-prop check`). Push to `env/c-worlds` only.
4. Run `tools/ci/check_all.sh --env c` (must PASS before "ready for integration").
5. Update `docs/status/env_c.md` (template: docs/process/communication.md §3), commit, push.
6. Message the lead with `send_message` (session `session_01FCtEudjuevi6MHipm4R11R`):
   `[ENV C] status @ <sha>; ready: yes/no; questions: QC-n...; review requested: G0 glasshouse`.
   If the tool is not loaded, use ToolSearch `select:mcp__claude-code-remote__send_message`.
