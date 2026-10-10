# Team structure, environments, and communication protocol

Owner: **LEAD**.

## 1. The four sessions

| Role | What it is | Branch it pushes to | Owns |
|---|---|---|---|
| **LEAD** (orchestrator) | Claude Code cloud session that created this repo | `claude/dreamy-hamilton-pc7vck` (= **trunk**, the integration branch) | architecture, contracts, docs, core/, contracts/, CI, integration tests, merges |
| **ENV A — Core Systems & AI** | Separate Claude Code cloud session, own container | `env/a-core` | `game/systems/**`, `game/tests/a/**`, `docs/status/env_a.md` |
| **ENV B — Content & Progression** | Separate Claude Code cloud session, own container | `env/b-content` | `game/content/**`, `game/assets/weapons/**`, `tools/blender/weapons/**`, `game/tests/b/**`, `docs/status/env_b.md` |
| **ENV D — Characters & Art Production** (D-027) | Separate Claude Code cloud session, own container | `env/d-art` | characters, animations, masks, `char_` materials, officer style-sample renders (see owners.json) |
| **ENV C — Worlds & Art** | Separate Claude Code cloud session, own container | `env/c-worlds` | `game/world/**`, `game/assets/**` (except weapons), `tools/blender/**` (except weapons), `tools/texgen/**`, `tools/audiogen/**`, `tools/levelcheck/**`, `docs/levels/**`, `docs/design/heists/**` (drafts), `game/tests/c/**`, `docs/status/env_c.md` |

The authoritative ownership map is `tools/ci/owners.json`. `tools/ci/check_ownership.py <env>`
fails if an env branch diverges from trunk in any file it does not own.

Each environment is a **separate session with its own container, tools, and subagents**. Inside its
domain an environment works subagentically (spawns its own Agent subtasks in parallel for
independent pieces) but its session is the single accountable owner of its branch.

### Live sessions

| Role | Session id | Branch |
|---|---|---|
| LEAD | `session_01FCtEudjuevi6MHipm4R11R` | `claude/dreamy-hamilton-pc7vck` |
| ENV A | `session_016DAFQRw44j8Tz7NA7mCGJw` | `env/a-core` |
| ENV B | `session_01UY8DitCKjvthQK7cYwvcja` | `env/b-content` |
| ENV C | `session_01V39kctNgrNn7iYUNoTEiNF` | `env/c-worlds` |
| ENV D | (see decisions D-027) | `env/d-art` |

Sessions talk with the `claude-code-remote` `send_message` tool. Environments message only the lead.

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

* Envs report **only to the lead**, never to each other.
* After pushing a status update an env sends the lead session a short message:
  `"[ENV A] status updated @ <sha>; ready-for-integration: yes; questions: QA-3, QA-4"`.
* The lead dispatches tasks by message to each env session, always referencing the
  task id in `docs/roadmap.md` and the contracts that apply.
* Cross-env needs ("ENV A needs a `KeycardSlot` with a facing marker") are written as a
  **question in the asking env's status file**. The lead answers by updating a contract or
  appending to `docs/decisions.md`, then notifies **both** envs. **Nothing is agreed until it is
  written in docs on trunk.**

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
