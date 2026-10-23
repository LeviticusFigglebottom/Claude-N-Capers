# CAPERWORKS: shared rules for every Claude session in this repo

This is an original co-op heist game in **Godot 4.7.2** with Payday 2-faithful mechanics. Team v3 (D-086):
the **LEAD** (orchestrator) plus five Claude Code cloud sessions: ENV A, ENV B, ENV C, ENV D, ENV P (all active since D-153).

## Who am I?
Look at your git branch:
- `claude/dreamy-hamilton-pc7vck`: you are the **LEAD** (trunk). Read `docs/process/communication.md`.
- `env/a-core`: you are **ENV A**. Read and follow `envs/a_core/CLAUDE.md` now.
- `env/b-content`: you are **ENV B**. Read and follow `envs/b_content/CLAUDE.md` now.
- `env/c-worlds`: you are **ENV C**. Read and follow `envs/c_worlds/CLAUDE.md` now.
- `env/d-art`: you are **ENV D**. Read and follow `envs/d_art/CLAUDE.md` now.
- `env/p-play`: you are **ENV P**. Read and follow `envs/p_play/CLAUDE.md` now.
- Any other branch: your dispatch message says your role; if it doesn't, you are the LEAD's helper and touch nothing on trunk.

## Always
- `docs/` is the knowledge base, and **nothing is agreed until it is written there on trunk**.
  Start with `docs/architecture.md`, `docs/roadmap.md`, `docs/design/pd2_fidelity.md`,
  `docs/contracts/README.md` and `docs/decisions.md`.
- Only touch files your environment owns (`tools/ci/owners.json`). Everything else: ask the lead.
- Typed GDScript, Godot conventions from architecture.md §6/§8. No global `randi()`/`randf()`;
  use `GameRng.stream(&"name")`. Never assume a single player.
- Units: meters and seconds; PD2 display units for health, armor and damage.
- No third-party art or audio assets of any kind. Third-party code/tools are fine; record them in
  `docs/third_party.md` via the lead.
- Validate before you push with **targeted** checks only (D-088): gdlint on changed files, `check_ownership.py <env>`,
  `check_banned.py`, the affected test files, plus windowed verification (D-086). The full `check_all` is the lead's, occasionally. Godot is at `/opt/godot/godot`
  (the SessionStart hook installs it, or run `bash tools/setup/install_godot.sh`).
- Never force-push. Never push to a branch other than your own.
- Commit messages: `[A1-03] short summary` (task id from docs/roadmap.md).
