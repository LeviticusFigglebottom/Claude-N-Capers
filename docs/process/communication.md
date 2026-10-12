# Team structure, environments, and communication protocol

Owner: **LEAD**.

## 1. The team (Grok Bot agents, D-078)

Since 2026-10-12 the team is a set of **Grok Bot agents** on one shared Linux box (Aaron's Grok Bot computer).
The earlier Claude Code cloud sessions and the WSL-local subagents are retired; their unpushed work is on GitHub as
`backup/2026-10-12/*`. Nobody works in the WSL distro or the Windows checkout on Aaron's PC.

| Role | Agent id | Clone on the box | Branch it pushes to | Owns |
|---|---|---|---|---|
| **LEAD** | (lead agent) | `/workspace/cnc-team/lead` | `claude/dreamy-hamilton-pc7vck` (= **trunk**) | architecture, contracts, docs, core/, CI, integration tests, merges |
| **ENV A — Core Systems & AI** | `d7c2f4bb-5bea-4fc5-92cf-7e3ab20a4989` | `/workspace/cnc-team/env-a` | `env/a-core` | `game/systems/**`, `game/tests/a/**`, `docs/status/env_a.md` |
| **ENV B — Content & Progression** | `ccd1c890-1137-4e8a-a422-afc12a60c7bd` | `/workspace/cnc-team/env-b` | `env/b-content` | `game/content/**`, weapons, `game/tests/b/**`, `docs/status/env_b.md` |
| **ENV C — Worlds & Art** | `ff4866f2-1d02-4efa-a2d8-53aa78a87e49` | `/workspace/cnc-team/env-c` | `env/c-worlds` | `game/world/**`, assets (non-weapon/char), tools/blender, texgen, audiogen, levelcheck, `docs/levels/**`, `game/tests/c/**` |
| **ENV D — Characters & Art** | `a9ad80ca-9f0c-4442-a4c1-3bef16990422` | `/workspace/cnc-team/env-d` | `env/d-art` | characters, animations, masks, `char_` materials (see owners.json) |
| **ENV P — Playability** | `3d922e3f-065c-4ebc-857e-dc8cc2e404e9` | `/workspace/cnc-team/env-p` | `env/p-play` | `game/systems/player/**`, `fp_viewmodel*`, `crew_tweak.*`, `game/tests/p/**` |

Shared toolchain (installed once by the LEAD): Godot 4.7.2 `/opt/godot/godot`, Blender 4.5.14 `/opt/blender/blender`,
pip deps from `tools/requirements.txt` (gdlint in `~/.local/bin`), xvfb-run. The box is shared: run long Godot
suites under `timeout`, Blender with `--threads 1`, and don't start more than one full check_all per env at a time.

The authoritative ownership map is `tools/ci/owners.json`. `tools/ci/check_ownership.py <env>`
fails if an env branch diverges from trunk in any file it does not own.

Each environment is a **separate session with its own container, tools, and subagents**. Inside its
domain an environment works subagentically (spawns its own Agent subtasks in parallel for
independent pieces) but its session is the single accountable owner of its branch.

### Coordination surfaces
* **BOARD** `/workspace/cnc-team/BOARD.md` (on the box, newest entry on top, `[YYYY-MM-DD HH:MM ET] [ROLE] text`):
  short-lived coordination: toolchain state, who is merging, blockers, pushes, queue changes.
* **SendToAgent** (Grok Bot agent messaging, ids in the table above): direct messages. Delivered on the
  recipient's next turn, not live, so put everything needed in one message.
* **docs/ on trunk**: anything durable (decisions, contracts, status). Nothing is agreed until it is in docs on trunk.

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

* Envs report **to the lead** with SendToAgent and a BOARD line; they do not task each other.
* After pushing (or, for ENV P, committing) a checked unit an env posts on BOARD and sends the lead:
  `"[ENV A] status @ <sha>; check_all: PASS; ready-for-integration: yes; questions: QA-3"`.
* The lead dispatches tasks by SendToAgent (mirrored on BOARD), referencing the roadmap / playability-list id
  and the contracts that apply.
* Cross-env needs are written as a **question in the asking env's status file**; the lead answers in a contract
  or `docs/decisions.md` and notifies both envs.
* Pushing to trunk needs the lead's gate (check_all PASS) and the product owner's approval; never force-push.

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
