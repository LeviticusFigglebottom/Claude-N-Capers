# Team structure, environments, and communication protocol

Owner: **LEAD**.

## 1. The team (team v3: Claude Code cloud sessions, D-086)

Since 2026-10-13 the team is a **LEAD Claude Code session plus dispatched Claude Code cloud sessions (P, B, A; C from D-104)**, each in
its own container with its own clone, tools and subagents. The Grok Bot box (D-078: BOARD.md, SendToAgent,
`/workspace/cnc-team/*`) is retired; ignore any reference to it. Session ids are in `docs/process/board.md`.

| Role | Status | Branch it pushes to | Owns (authoritative: `tools/ci/owners.json`) |
|---|---|---|---|
| **LEAD** | active | `claude/dreamy-hamilton-pc7vck` (= **trunk**) | architecture, contracts, docs, core/, project.godot, CI, integration tests, merges |
| **ENV P — Player & Input** | active | `env/p-play` | `game/systems/player/**`, `fp_viewmodel*`, `crew_tweak.*`, `game/tests/p/**` |
| **ENV B — Content & UI** | active | `env/b-content` | `game/content/**` (all UI), weapons, `docs/design/ui/**`, `game/tests/b/**` |
| **ENV A — Core Systems & Heist Loop** | active | `env/a-core` | `game/systems/**` (minus P's), `game/world/heists/**` + `game/world/props/**` during the pass (D-086), `game/tests/a/**` |
| **ENV C — Worlds & Art** | active (D-104) | `env/c-worlds` | `game/world/**`, assets, tools/blender, texgen, audiogen, levelcheck, `docs/levels/**`, heist design docs (A co-owns existing heists' missions/markers, D-104) |
| ENV D — Characters & Art | dormant | `env/d-art` | (owners.json) |

Toolchain per container: Godot 4.7.2 at `/opt/godot/godot` (SessionStart hook, or `bash tools/setup/install_godot.sh`),
`pip install -r tools/requirements.txt` (gdlint), `xvfb-run` for windowed runs. Full `check_all` takes ~40 min on
4 cores: run single test dirs while iterating (`tools/ci/run_tests.sh p`), the full gate before a push.

### Coordination surfaces
* **`docs/process/board.md`** (trunk, LEAD-written): live state: session ids, who works on what, merge rounds,
  open questions and their answers, blockers. Read it at the start of every work session and after each lead message.
* **`send_message`** (claude-code-remote MCP): env → lead reports and questions; lead → env dispatches and answers.
  Messages arrive on the recipient's next turn, so put everything needed in one message. Envs may message **each
  other directly** for quick technical questions (a signal name, "is X already done?") and must cc the lead with a
  one-line summary; anything that changes a contract, ownership, or priorities goes through the lead.
* **`docs/` on trunk**: anything durable (decisions, contracts, issue list, status). Nothing is agreed until it is in docs on trunk.
* **Status files** `docs/status/env_<x>.md` on the env branch: end-of-session log and resume point (§3).

### Verification rule (D-086)
A player-facing fix is **verified** only when it has been seen working in a **windowed** run (`xvfb-run` with a real
display server, not `--headless`), with a screenshot or a test that runs windowed. Tests that fake engine state
(`test_assume_captured`, teleports, intent injection) are fine as regression tests but do not count as verification.

## 2. Branch flow

```
trunk (claude/dreamy-hamilton-pc7vck)  <── LEAD merges after review
   │  ▲            ▲            ▲
   ▼  │            │            │
 env/a-core    env/b-content  env/c-worlds
```

1. Envs start each work session with `git fetch origin && git merge origin/claude/dreamy-hamilton-pc7vck`
   (merge, never rebase, so the lead's review history stays valid).
2. Envs commit small, focused commits and push to their own branch only.
3. When a task is ready for integration, the env updates its status file, makes sure
   `tools/ci/check_all.sh --env <a|b|c>` passes, pushes, and notifies the lead.
4. The lead reviews (see §5) and merges the env branch into trunk with a merge commit,
   or replies with rejection reasons in `docs/decisions.md` / the env's next task.
5. Nobody force-pushes. Nobody pushes to another env's branch or to trunk except the lead.

## 3. Reporting: status files

Every env updates `docs/status/env_<x>.md` **at the end of every work session** using this exact
template (newest entry on top, keep the last 10 entries):

```
## <YYYY-MM-DD HH:MM UTC> — <task id(s)>
### Done
- ...  (commit shas)
### In progress
- ...
### Blocked
- ... (what, on whom)
### Questions for lead
- Q<env>-<n>: ...  (one question per bullet, self-contained)
### Ready for integration
- yes/no; `check_all.sh --env x` result: PASS/FAIL
```

## 4. Messaging

* Envs report **to the lead** with `send_message`; they never task each other (peer questions only, §1).
* After pushing a checked unit an env sends the lead:
  `"[ENV P] pushed <sha>; check: <what ran> PASS; verified windowed: <how>; ready-for-integration: yes; questions: QP-3"`.
* The lead dispatches tasks by `send_message` and mirrors them in `docs/process/board.md`, referencing the
  playability-list id (`docs/process/playability_pass.md`) or roadmap id and the contracts that apply.
* Cross-env needs: a question in the asking env's status file **and** in the message to the lead; the lead answers
  in a contract or `docs/decisions.md`, notes it on the board, and notifies both envs.
* After each merge round the lead sends "round N ON ORIGIN: trunk <sha>"; envs merge trunk before their next push.

## 5. Lead review checklist (before every merge)

1. `tools/ci/check_all.sh --env <x>` on a fresh merge of trunk + env branch: import, lint,
   banned APIs, ownership, unit tests, integration gate, `validate_level`.
2. Contracts respected: no signal/schema/node-name drift; no new cross-env coupling.
3. Duplication scan: no reimplementation of something another env or core already provides
   (grep for similar class names, utility functions). Redundant work is rejected.
4. Single-player assumptions: grep for `get_first_node_in_group("player")`, raw `Input.` outside
   input components, `randi()`/`randf()`, absolute paths to other envs' internals.
5. Data-driven: no balance constants hard-coded in systems.
6. For level work: every screenshot in `docs/levels/<heist>/` personally reviewed; implausible
   geometry/props = rejection with a list of shots and issues.
7. Decision-log entry for the merge (`docs/decisions.md`).

## 6. Contracts

`docs/contracts/` holds every cross-env interface. A contract file has a version header.
Only the lead edits contracts. A breaking change bumps the version, is logged in
`docs/decisions.md`, and is announced to all envs with the migration required.

## 7. Utilization policy (product owner directive, D-027)

No environment may sit idle or blocked while useful work exists:
* When an env's queue for the current phase runs dry or is blocked, the lead **pulls forward** the
  next independent work from a later phase in that env's own domain (e.g. ENV B → P4 progression data/UI).
* When one env is the bottleneck, the lead may (a) **carve out** part of its domain to another env, with
  an owners.json change and a decision entry, or (b) **spin up an additional environment** with its own
  CLAUDE.md, branch and ownership slice.
* Tandem work across envs always goes through ownership and contracts. Nobody edits another env's
  files. Handoffs (e.g. a script for another env to run) are pushed to trunk first via the lead.
* Each status message must say whether the env has queued work for at least the next ~2 hours. If not,
  the lead dispatches more in the same loop.
