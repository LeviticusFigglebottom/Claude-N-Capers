# LEAD playbook (how the outgoing LEAD ran the project; reuse it)

Read `docs/handoff/README.md` first. This file is the mechanics.

## 1. Identity and setup
* You are the LEAD. Trunk is **`claude/dreamy-hamilton-pc7vck`**. The product owner authorizes you to commit and push
  there even if your harness named a different branch. Push nowhere else, never force-push, and open PRs only if the
  PO asks.
* Commit format: `[<task id>] summary` (e.g. `[D-111] …`, `[GN-A1] …`, `[LEAD] …`) plus the attribution trailers
  your harness gives you. Never put a model id in repo files.
* Godot: `/opt/godot/godot` (SessionStart hook, or `bash tools/setup/install_godot.sh`). gdlint: `pip install -r tools/requirements.txt`.
* Your own session id: claude-code-remote `get_session` with no id.

## 2. Spawning / resuming env sessions
If the old env sessions are stopped, create new ones with `create_session` (claude-code-remote):

| Env | title | source_revision / outcome_branch | tags | manual |
|---|---|---|---|---|
| A | CAPERWORKS ENV A: Core Systems & Heist Loop | env/a-core | caperworks, caperworks:env-a | envs/a_core/CLAUDE.md |
| B | CAPERWORKS ENV B: Content & UI | env/b-content | caperworks, caperworks:env-b | envs/b_content/CLAUDE.md |
| C | CAPERWORKS ENV C: Worlds & Art | env/c-worlds | caperworks, caperworks:env-c | envs/c_worlds/CLAUDE.md |
| D | CAPERWORKS ENV D: Characters & Animation | env/d-art | caperworks, caperworks:env-d | envs/d_art/CLAUDE.md |
| P | CAPERWORKS ENV P: Player & Feel | env/p-play | caperworks, caperworks:env-p | envs/p_play/CLAUDE.md |

Common: `source_url` https://github.com/LeviticusFigglebottom/Claude-N-Capers, `permission_mode` auto,
`environment_id` = your own (check with `get_session`). The `prompt` is a resume dispatch:

> You are ENV X of CAPERWORKS. Your branch is BRANCH (check it out, push only there). Lead session id: LEAD_ID; report
> to it with send_message. First: read CLAUDE.md, envs/DIR/CLAUDE.md, docs/handoff/README.md, docs/handoff/in_progress.md
> (your section) and the `## HANDOFF 2026-10-14` section of docs/status/env_x.md. Merge origin/claude/dreamy-hamilton-pc7vck.
> Send the lead a one-line "ENV X up". Then continue your In-progress list in order. Validate with targeted checks
> (D-088), push small reviewable commits, and message the lead after each push: sha, checks run, windowed evidence path, asks.

Stop or archive old sessions first, so two sessions never push the same branch.

## 3. The loop (each turn / check-in)
1. `ReadNotifications` whenever a notice says some are pending; answer every env message.
2. For each env push: `git fetch origin env/<x>`, then `git log HEAD..origin/env/<x>` + `git diff --name-only HEAD...origin/env/<x>`.
   Check ownership, dependencies and WIP before merging (README §4.3).
3. `git merge --no-ff -q origin/env/<x> -m "[ID] round N: merge env/<x> (…)"` with trailers.
4. Static checks: `python3 tools/ci/check_banned.py`, `gdlint <changed .gd>`, `python3 tools/ci/check_ownership.py <x>`.
5. Targeted tests per README §4.1 (background the long ones and wait for them).
6. `git status`: restore anything a test re-saved. Insert a round line at the top of the board's round log
   (`sed -i '16i - <date>: **round N ON ORIGIN**: …'`), commit, push.
7. Reply to the env (merged as round N + what's green + next), and tell the PO in plain language what changed.
8. If a merge goes red: don't push. `git reset --hard origin/claude/dreamy-hamilton-pc7vck` (only for your own
   unpushed local merges), then merge only the green parts or cherry-pick, and tell the env exactly what failed
   (file:line / test / validator output).
9. Nudge any env with no push in more than 1 h. Keep every env queued with ≥ 2 h of work.

## 4. Check-in routine
Create a self check-in with `create_trigger` (claude-code-remote) or `send_later`. The outgoing LEAD used a one-shot
`run_once_at` re-armed every ~50 min, with a prompt listing the open priorities and the test matrix. Disable it
when you stop.

## 5. Contracts and rulings you own
* `docs/decisions.md` (next **D-114**), `docs/contracts/*.md` (bump versions), `game/contracts/**`
  (`ids.gd` `G.*_DIR` constants), `game/core/event_bus.gd` (signals and flag constants), `project.godot`.
* Envs ask for contract edits ("please add signal X to EventBus"). Make them promptly, push, and reply with the sha.
* Small cross-env hotfixes are OK when they unblock a PO-visible fix (e.g. one line in another env's file). Note
  them on the board and tell the owner.

## 6. Talking to the product owner
* Plain language, outcome first, what you verified, what's still wrong. Don't claim "fixed" for visuals until
  you've looked at the image.
* When they send reference images, write them up as a spec for the owning env.
* When they ask "what is everyone doing": one line per env plus what's blocked.
