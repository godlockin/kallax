# Slash Commands Reference

> Complete reference for all 26 KALLAX slash commands (in-tool invocations).

---

## §0 Smart Router (EPIC-127) — `/kallax <任意诉求>` 一键入口

**新加**(2026-07-20): 主公只打 `/kallax <诉求>`, 框架**自动路由**到下方 26 命令之一。

| 主公原话样例 | 自动路由到 |
|---|---|
| `/kallax` (无参) | `/kallax-help` |
| `/kallax 现在状态` / `/kallax 进度` | `/kallax-status` |
| `/kallax 帮我看 ticket` / `/kallax 看板` | `/kallax-board` |
| `/kallax 召唤架构师看微服务` | `/kallax-expert architect 微服务` |
| `/kallax 全员评审新功能` | `/kallax-panel 新功能` |
| `/kallax fastapi 怎么用` | `/kallax-ask fastapi 怎么用` |
| `/kallax 启动` / `/kallax 接 master` | `/kallax-start master` |

**机制**: Claude Code 读 `.claude/commands/kallax.md` 的 `description:`, 看全 26 命令表 + 主公诉求 → 自动挑 sub-command 执行。每次先打印 1 行 `🔀 routed: /kallax-<subcmd>`。

**完整路由表 + 路由失败防范** (含 parameters error 的 6 大元凶): 见 `.claude/commands/kallax.md`。

> 路由命中但不熟用法 → 仍然 fallback 跑 `/kallax-<subcmd> --help` 看详细说明。

---

This document covers the **slash commands** invoked from inside the AI tool (Claude Code / opencode / Codex / Gemini). For the **CLI commands** (`kallax task claim`, `kallax conductor heartbeat`, etc.) used from a terminal, see [cli-reference.md](cli-reference.md).

**Source paths**:
- Claude Code: `.claude/commands/kallax-*.sh` (executable bash scripts)
- opencode: `.opencode/command/kallax-*.md` (markdown-wrapped, with embedded bash)
- Codex: `~/.codex/prompts/kallax-*.md`
- Gemini: `~/.gemini/commands/kallax-*.md`

**Install**: `bash scripts/install.sh --target=auto` (see [INSTALL-MULTI-TOOL.md](../guides/INSTALL-MULTI-TOOL.md))

**Built-in help**: Every command supports `--help` / `-h` flag for in-tool usage.

---

## How to Use This Document

Slash commands are organized by **role** (who typically invokes them):

| Section | Role | Count | Purpose |
|---|---|---|---|
| [§1 Quick Commands](#1-quick-commands) | All | 3 | Start/stop/check status (everyone uses) |
| [§2 Performer Commands](#2-performer-commands) | Performer | 4 | Claim → work → submit PR (do work) |
| [§3 Conductor Commands](#3-conductor-commands) | Conductor | 7 | Review/merge/board (orchestrate) |
| [§4 Analysis & Design](#4-analysis--design) | All | 7 | Ask experts, panel, design help (think) |
| [§5 Configuration](#5-configuration) | All | 3 | Init/role/mode (configure) |
| [§6 Workflow](#6-workflow) | All | 2 | Save/resume (continuity) |
| **Total** | | **26** | |

Each entry has: **syntax** · **args** · **what it does** · **output** · **when to use** · **example** · **related** · **role required** · **source**.

---

## 1. Quick Commands

These three commands are used by **every role** to start, check, or get help.

---

### `/kallax-start` — Start KALLAX in current project

| Field | Value |
|---|---|
| **Syntax** | `/kallax-start [role]` |
| **Args** | `role` (optional, prompts if missing): `master` / `conductor` / `performer` |
| **What it does** | Validates role, writes `instance_config.yml`, registers via `/api/agents/register` |
| **Output** | `KALLAX <role> started` + instance ID + role-specific next steps |
| **When to use** | You begin a new KALLAX session in this project |
| **Example** | `/kallax-start conductor` |
| **Role required** | None |
| **Related** | `/kallax-init`, `/kallax-role`, `/kallax-mode` |
| **Source** | `.claude/commands/kallax-start.sh` |

**Typical next step**: Run `/kallax-status` to verify state, then `/kallax-claim` (Performer) or `/kallax-board` (Conductor).

---

### `/kallax-status` — Show current system and task status

| Field | Value |
|---|---|
| **Syntax** | `/kallax-status` |
| **Args** | None |
| **What it does** | Prints role/branch + queries `/health` and `/stats` + role-specific checklist |
| **Output** | Role, project, branch, task/agent counts; Conductor 5-Q checklist or Performer checklist |
| **When to use** | You want a quick state snapshot of KALLAX + the system |
| **Example** | `/kallax-status` |
| **Role required** | None |
| **Related** | `/kallax-board`, `/kallax-instances`, `/kallax-check-progress` |
| **Source** | `.claude/commands/kallax-status.sh` |

---

### `/kallax-help` — Show all available commands and resources

| Field | Value |
|---|---|
| **Syntax** | `/kallax-help` |
| **Args** | None |
| **What it does** | Prints grouped command cheat-sheet (Quick/Performer/Conductor/Analysis/Config/CLI) |
| **Output** | Static list of 26 slash commands + 12 CLI commands + resource paths |
| **When to use** | You forgot a command name or want a quick reference |
| **Example** | `/kallax-help` |
| **Role required** | None |
| **Related** | `/kallax-list`, `/kallax-start` |
| **Source** | `.claude/commands/kallax-help.sh` |

> For detailed per-command help with args, examples, and outputs, see this document or use `/kallax-<cmd> --help`.

---

## 2. Performer Commands

Use these when you are a **Performer** claiming a task and shipping a PR.

---

### `/kallax-claim` — Claim an available task (auto-creates worktree)

| Field | Value |
|---|---|
| **Syntax** | `/kallax-claim [TASK_ID]` |
| **Args** | `TASK_ID` (optional, prompts / auto-claims first pending) |
| **What it does** | Atomically claims a task via `kallax` CLI or API; creates isolated worktree |
| **Output** | Claimed task ID + `Task claimed successfully!` + next-step hints |
| **When to use** | You are a Performer ready to start a new ticket |
| **Example** | `/kallax-claim TICKET-EPIC-053-A` or just `/kallax-claim` to auto-pick |
| **Role required** | None (typically Performer) |
| **Related** | `/kallax-submit-pr`, `/kallax-task` |
| **Source** | `.claude/commands/kallax-claim.sh` |

**Pre-claim check**: Verify your worktree is clean (`/kallax-status`) and that the file scope doesn't overlap with other active Performers.

---

### `/kallax-submit-pr` — Complete task and submit PR for review (Saga 5-step)

| Field | Value |
|---|---|
| **Syntax** | `/kallax-submit-pr [TASK_ID]` |
| **Args** | `TASK_ID` (auto-detects from branch name `kallax/<id>`) |
| **What it does** | Runs Saga 5-step: **tests → lint → verify → commit → PR**. Then `kallax task complete` via CLI |
| **Output** | Per-step Saga progress + verify pass/fail + `PR submitted for review!` |
| **When to use** | You finished a task and want to land it for review |
| **Example** | `/kallax-submit-pr` (auto-detects) or `/kallax-submit-pr TICKET-EPIC-053-A` |
| **Role required** | None (typically Performer) |
| **Related** | `/kallax-claim`, `/kallax-verify-pr` |
| **Source** | `.claude/commands/kallax-submit-pr.sh` |

**Saga 5-step breakdown**:
1. `npm test` (or language-equivalent) — unit tests
2. `npm run lint` (or equivalent) — lint check
3. `bash scripts/verify/check-test-case-isolation.sh` (anti-fab)
4. `git add -A && git commit` (with structured message)
5. `gh pr create --base testing` (PR opens for Conductor review)

**Failure mode**: If any step fails, the script halts. Fix the issue, re-run.

---

### `/kallax-save` — Save current session state for later resumption

| Field | Value |
|---|---|
| **Syntax** | `/kallax-save` |
| **Args** | None |
| **What it does** | Snapshots role/branch/git status/commits into `sessions/<timestamp>.json` |
| **Output** | Saved file path + optional commit of uncommitted changes |
| **When to use** | You're ending a session and want to pick up later |
| **Example** | `/kallax-save` |
| **Role required** | None |
| **Related** | `/kallax-resume`, `/kallax-status` |
| **Source** | `.claude/commands/kallax-save.sh` |

**Saved state includes**: role, branch, working tree status, recent commits, current task (if any).

---

### `/kallax-resume` — Resume from a saved session

| Field | Value |
|---|---|
| **Syntax** | `/kallax-resume` |
| **Args** | None (prompts to pick session) |
| **What it does** | Lists saved session JSONs, restores role/branch config from latest |
| **Output** | Session list + `Session resumed` + role/branch switch prompt |
| **When to use** | You're picking up work from a previous session |
| **Example** | `/kallax-resume` |
| **Role required** | None |
| **Related** | `/kallax-save`, `/kallax-start` |
| **Source** | `.claude/commands/kallax-resume.sh` |

---

## 3. Conductor Commands

Use these when you are a **Conductor** orchestrating Performers and merging PRs.

---

### `/kallax-review-pr` — Review a pull request (5 levels Gate Review)

| Field | Value |
|---|---|
| **Syntax** | `/kallax-review-pr [PR_NUMBER] [BASE_BRANCH]` |
| **Args** | `PR_NUMBER` (optional, prompts if missing), `BASE_BRANCH` (default: `main`) |
| **What it does** | Runs 4 gates: **preflight** → **architecture** → **security** → **performance**; prompts decision |
| **Output** | Per-gate results + approve/comment/reject review via `gh` CLI |
| **When to use** | You're a Conductor reviewing a Performer's PR |
| **Example** | `/kallax-review-pr 123 testing` |
| **Role required** | **Conductor (enforced via `require_role`)** |
| **Related** | `/kallax-verify-pr`, `/kallax-merge` |
| **Source** | `.claude/commands/kallax-review-pr.sh` |

**5 levels Gate breakdown**:
1. **Preflight** — file scope overlap check (worktree isolation)
2. **Architecture** — CLAUDE.md Rule compliance, no anti-patterns
3. **Security** — secrets scan, auth/authz check
4. **Performance** — no N+1 queries, no premature optimization

**Decision**: After all 4 gates, you (Conductor) choose: `approve` / `comment` / `request changes` / `reject`.

---

### `/kallax-verify-pr` — Verify PR output before merge (5 levels Fact-Forcing)

| Field | Value |
|---|---|
| **Syntax** | `/kallax-verify-pr [PR_NUMBER]` |
| **Args** | `PR_NUMBER` (optional, prompts if missing) |
| **What it does** | Runs **L1 existence** → **L2 substance** (no TODOs) → **L3 wiring** (no `@ts-ignore`/`:any`) → **L4 data flow** (CI green) |
| **Output** | Per-level pass/warn + `All 4 levels passed` |
| **When to use** | You want to confirm a PR passes the 4-level fact check before merging |
| **Example** | `/kallax-verify-pr 123` |
| **Role required** | None (typically Conductor) |
| **Related** | `/kallax-review-pr`, `/kallax-merge` |
| **Source** | `.claude/commands/kallax-verify-pr.sh` |

**5 levels Fact-Forcing** (跟 5 levels (L1-L5),配合):
- L1 — Existence: files exist in git diff
- L2 — Substance: real logic, not stubs (no `TODO` in critical paths)
- L3 — Wiring: correct imports/exports, type compatibility
- L4 — Data flow: integration tests pass, E2E coverage

---

### `/kallax-merge` — Merge an approved PR

| Field | Value |
|---|---|
| **Syntax** | `/kallax-merge [PR_NUMBER]` |
| **Args** | `PR_NUMBER` (optional, lists open PRs if missing) |
| **What it does** | 3-step check (CI passing, approvals, squash-merge) via `gh` CLI |
| **Output** | CI status, approval count, `merged successfully` or error |
| **When to use** | A PR is approved and you're ready to land it on `main` |
| **Example** | `/kallax-merge 123` |
| **Role required** | **Conductor** |
| **Related** | `/kallax-review-pr`, `/kallax-verify-pr` |
| **Source** | `.claude/commands/kallax-merge.sh` |

**Safety checks before merge**:
- CI green on the PR branch
- ≥1 Conductor approval comment
- No merge conflicts with `main`
- File scope does not conflict with in-flight work

---

### `/kallax-review-merge` — Combined review + merge workflow

| Field | Value |
|---|---|
| **Syntax** | `/kallax-review-merge [PR_NUMBER]` |
| **Args** | `PR_NUMBER` (optional, prompts if missing) |
| **What it does** | Sequentially sources `verify-pr` → `review-pr` → `merge` sub-scripts |
| **Output** | Aggregated output of all 3 stages; aborts on any step failure |
| **When to use** | You want a one-shot verify → review → merge pipeline |
| **Example** | `/kallax-review-merge 123` |
| **Role required** | **Conductor** |
| **Related** | `/kallax-verify-pr`, `/kallax-review-pr`, `/kallax-merge` |
| **Source** | `.claude/commands/kallax-review-merge.sh` |

---

### `/kallax-board` — Show interactive ticket board

| Field | Value |
|---|---|
| **Syntax** | `/kallax-board` |
| **Args** | None |
| **What it does** | Lists P0/P1, in-progress, in-review (open PRs), recently completed |
| **Output** | Grouped task lists per priority/status + total ticket count + command hints |
| **When to use** | You want a kanban-style overview of current work |
| **Example** | `/kallax-board` |
| **Role required** | None |
| **Related** | `/kallax-check-progress`, `/kallax-status` |
| **Source** | `.claude/commands/kallax-board.sh` |

---

### `/kallax-instances` — List active Conductor/Performer instances

| Field | Value |
|---|---|
| **Syntax** | `/kallax-instances` |
| **Args** | None |
| **What it does** | Lists registered agents via `kallax team:status` or `/api/agents` |
| **Output** | Active instance list + lifecycle diagram + heartbeat/stale thresholds |
| **When to use** | You want to see who is currently running |
| **Example** | `/kallax-instances` |
| **Role required** | None (mostly Conductor view) |
| **Related** | `/kallax-status`, `/kallax-check-progress` |
| **Source** | `.claude/commands/kallax-instances.sh` |

---

### `/kallax-check-progress` — Check team progress and milestone status

| Field | Value |
|---|---|
| **Syntax** | `/kallax-check-progress` |
| **Args** | None |
| **What it does** | Counts tasks by status and computes overall completion percentage |
| **Output** | Total/Completed/In-Progress counts, completion %, ASCII progress bar |
| **When to use** | You want a milestone progress snapshot |
| **Example** | `/kallax-check-progress` |
| **Role required** | None |
| **Related** | `/kallax-board`, `/kallax-instances` |
| **Source** | `.claude/commands/kallax-check-progress.sh` |

---

## 4. Analysis & Design

These commands help with **thinking, designing, and getting expert opinions** before/after coding.

---

### `/kallax-ask` — Ask a question to the expert panel

| Field | Value |
|---|---|
| **Syntax** | `/kallax-ask "<question>"` |
| **Args** | `question` (optional, prompts if missing) |
| **What it does** | Keyword-routes a question to relevant experts (`architect` / `backend` / `frontend` / `ux` / `product` / `security` / `performance`) |
| **Output** | List of selected experts + per-expert `/kallax-expert` invocation suggestions |
| **When to use** | You want auto-routing of a question to the right experts |
| **Example** | `/kallax-ask "How should we structure the WebSocket reconnection logic?"` |
| **Role required** | None |
| **Related** | `/kallax-expert`, `/kallax-panel` |
| **Source** | `.claude/commands/kallax-ask.sh` |

**Keyword routing map** (跟 KALLAX-GLOSSARY.md §8,配合):
- `architect|design|system|structure|pattern` → `architect`
- `api|backend|database|data|server|endpoint` → `backend`
- `frontend|ui|component|react|vue|css|style` → `frontend`
- `ux|user|usability|accessib|interact` → `ux`
- `product|requirement|priority|roadmap|milestone` → `product`
- `security|vuln|auth|penetrat|exploit` → `security`
- `performance|slow|optimize|latency|throughput` → `performance`

If no keyword matches, defaults to `architect backend ux product` (core 4).

---

### `/kallax-expert` — Summon a specific expert for analysis

| Field | Value |
|---|---|
| **Syntax** | `/kallax-expert <role> [context]` |
| **Args** | `role` (required), `context` (optional) |
| **What it does** | Locates expert profile file (core or extended) and prints analysis context |
| **Output** | Expert name, context, expert profile path, prompt to feed details |
| **When to use** | You want deep analysis from one specific expert role |
| **Example** | `/kallax-expert backend "Should we use Redis pub/sub or Postgres LISTEN/NOTIFY for this queue?"` |
| **Role required** | None |
| **Related** | `/kallax-ask`, `/kallax-panel`, `/kallax-list` |
| **Source** | `.claude/commands/kallax-expert.sh` |

**5 core experts**: `architect`, `backend`, `frontend`, `ux`, `product` — see `.claude/skills/kallax/default/<role>.md`.

**5+ extended experts**: `auditor-independent-witness`, `compliance-rule-merge`, `decision-gate-complex-only`, `process-engineering-self-verify`, `security-tool-bypass` — see `.claude/skills/kallax/extended/`.

---

### `/kallax-panel` — Launch full expert panel (5 experts + Conductor)

| Field | Value |
|---|---|
| **Syntax** | `/kallax-panel [TOPIC]` |
| **Args** | `TOPIC` (optional, prompts if missing) |
| **What it does** | Prints panel member list and 3-phase execution flow; saves a panel template |
| **Output** | `expert_panel_<timestamp>.md` template + per-expert `/kallax-expert` commands |
| **When to use** | You want a multi-perspective review on an EPIC / architecture decision |
| **Example** | `/kallax-panel "Evaluate the hybrid flag-controlled install design for v2.0.6"` |
| **Role required** | None (typically Conductor) |
| **Related** | `/kallax-expert`, `/kallax-ask`, `/kallax-office-hours` |
| **Source** | `.claude/commands/kallax-panel.sh` |

**3-phase execution flow**:
1. **Phase 1**: Each of 5 experts analyzes independently (parallel)
2. **Phase 2**: Conductor synthesizes findings, identifies conflicts
3. **Phase 3**: Master approves or requests deeper dive

---

### `/kallax-skill` — Execute a specific skill

| Field | Value |
|---|---|
| **Syntax** | `/kallax-skill <skill-name> [target]` |
| **Args** | `skill-name` (required), `target` (optional) |
| **What it does** | Locates skill markdown under `skills/*` and prints execution context |
| **Output** | Skill name, target, `skill will be loaded` notice |
| **When to use** | You want to invoke a specific capability (e.g. `tdd`, `security-review`, `kallax-init`) |
| **Example** | `/kallax-skill tdd "Add login form validation"` |
| **Role required** | None |
| **Related** | `/kallax-expert`, `/kallax-list` |
| **Source** | `.claude/commands/kallax-skill.sh` |

---

### `/kallax-list` — List all available experts, skills, and resources

| Field | Value |
|---|---|
| **Syntax** | `/kallax-list` |
| **Args** | None |
| **What it does** | Prints categorized tree of 5 core + 5+ extended experts and 16+ skills |
| **Output** | Static categorized list of experts (AI / Biz / Design / HR / etc) and skills |
| **When to use** | You want to discover what's available before summoning |
| **Example** | `/kallax-list` |
| **Role required** | None |
| **Related** | `/kallax-help`, `/kallax-expert` |
| **Source** | `.claude/commands/kallax-list.sh` |

---

### `/kallax-analyze` — Analyze project structure and dependencies

| Field | Value |
|---|---|
| **Syntax** | `/kallax-analyze [TARGET]` |
| **Args** | `TARGET` (default: `.`) |
| **What it does** | Scans project for file-type counts, git stats, dependency info, top-level dirs |
| **Output** | TS/Rust/Shell/Markdown/Config counts, commits, branches, contributors, last commit time, save path |
| **When to use** | You need a quick code-health overview of the current repo |
| **Example** | `/kallax-analyze .` or `/kallax-analyze ./src` |
| **Role required** | None |
| **Related** | `/kallax-review-analysis`, `/kallax-status` |
| **Source** | `.claude/commands/kallax-analyze.sh` |

---

### `/kallax-office-hours` — Requirements analysis (6 questions method)

| Field | Value |
|---|---|
| **Syntax** | `/kallax-office-hours [TOPIC]` |
| **Args** | `TOPIC` (optional, prompts if missing) |
| **What it does** | Prints the 6 YC-style forcing questions and saves a fillable template |
| **Output** | `requirements_<timestamp>.md` template in `.kallax/inbox/` |
| **When to use** | You start a fuzzy / ambiguous project and need to clarify scope |
| **Example** | `/kallax-office-hours "New EPIC: cross-team metrics dashboard"` |
| **Role required** | None |
| **Related** | `/kallax-panel`, `/kallax-analyze` |
| **Source** | `.claude/commands/kallax-office-hours.sh` |

**6 forcing questions** (跟 YC Office Hours,配合):
1. **Demand reality** — Who specifically needs this? How often? What pain?
2. **Status quo** — What do they do today? How painful is it?
3. **Desperate specificity** — Give one named example of a user with this pain
4. **Narrowest wedge** — What's the smallest first version that delivers value?
5. **Observation** — What have you personally observed vs. assumed?
6. **Future-fit** — Will this matter in 3 years? Why?

---

## 5. Configuration

These commands configure **KALLAX itself** (init, role, mode).

---

### `/kallax-init` — Initialize KALLAX in a new or existing project

| Field | Value |
|---|---|
| **Syntax** | `/kallax-init` |
| **Args** | None (prompts confirm) |
| **What it does** | Creates `.kallax/`, `confluence/`, `jira/`, `template/` dirs and default `config.yml` + `IDENTITY.md` |
| **Output** | Created directory tree, `config.yml`, `IDENTITY.md`; `KALLAX initialized successfully!` |
| **When to use** | You onboard KALLAX into a fresh project |
| **Example** | `/kallax-init` |
| **Role required** | None |
| **Related** | `/kallax-start`, `/kallax-role` |
| **Source** | `.claude/commands/kallax-init.sh` |

**Idempotent**: Safe to re-run; existing files are not overwritten without confirmation.

---

### `/kallax-role` — View or change agent role

| Field | Value |
|---|---|
| **Syntax** | `/kallax-role [conductor|performer]` |
| **Args** | `role` (optional, shows current if missing) |
| **What it does** | Prints current role, optionally writes new role to `instance_config.yml` |
| **Output** | Current / updated role + available-roles list |
| **When to use** | You need to check or switch the active role |
| **Example** | `/kallax-role` (show) or `/kallax-role conductor` (switch) |
| **Role required** | None |
| **Related** | `/kallax-mode`, `/kallax-start` |
| **Source** | `.claude/commands/kallax-role.sh` |

---

### `/kallax-mode` — Switch between operation modes

| Field | Value |
|---|---|
| **Syntax** | `/kallax-mode [conductor|performer|standalone]` |
| **Args** | `mode` (optional, prompts if missing) |
| **What it does** | Writes `instance_config.yml` with the chosen role / standalone flag |
| **Output** | Selected mode + responsibilities summary |
| **When to use** | You want to switch operational mode (Conductor / Performer / Standalone) |
| **Example** | `/kallax-mode conductor` |
| **Role required** | None |
| **Related** | `/kallax-role`, `/kallax-start` |
| **Source** | `.claude/commands/kallax-mode.sh` |

**3 modes**:
- `conductor` — orchestrates Performers, reviews PRs, merges
- `performer` — claims tasks, develops in worktree, submits PRs
- `standalone` — single-agent mode (no Conductor/Performer split, useful for solo dev)

---

## 6. Workflow

These commands help with **session continuity** — save your work, pick it up later.

---

### `/kallax-save` — Save current session state

See [§2.3](#kallax-save--save-current-session-state-for-later-resumption) for full reference.

---

### `/kallax-resume` — Resume from a saved session

See [§2.4](#kallax-resume--resume-from-a-saved-session) for full reference.

---

### `/kallax-review-analysis` — Review codebase analysis results

| Field | Value |
|---|---|
| **Syntax** | `/kallax-review-analysis` |
| **Args** | None |
| **What it does** | Shows most-changed files, test ratio, and knowledge-base size + recommendations |
| **Output** | Top-10 hot files, test-to-source ratio, memory count, health warnings |
| **When to use** | You want a code-knowledge health audit |
| **Example** | `/kallax-review-analysis` |
| **Role required** | None |
| **Related** | `/kallax-analyze`, `/kallax-phase-review` |
| **Source** | `.claude/commands/kallax-review-analysis.sh` |

---

### `/kallax-phase-review` — Phase-based project review

| Field | Value |
|---|---|
| **Syntax** | `/kallax-phase-review [PHASE]` |
| **Args** | `PHASE` (default: `all`) |
| **What it does** | Shows completed tasks / open PRs counts and 5-point review checklist |
| **Output** | `phase_review_<timestamp>.md` template in `.kallax/inbox/` |
| **When to use** | You reach a milestone and want to do a formal phase review |
| **Example** | `/kallax-phase-review PHASE-011` |
| **Role required** | **Conductor** |
| **Related** | `/kallax-check-progress`, `/kallax-review-pr` |
| **Source** | `.claude/commands/kallax-phase-review.sh` |

---

### `/kallax-task` — Quick task management shortcut

| Field | Value |
|---|---|
| **Syntax** | `/kallax-task [subcommand] [args]` |
| **Args** | Subcommand (optional) |
| **What it does** | Wraps `kallax task <subcommand>` for in-tool convenience |
| **Output** | Same as the wrapped `kallax task` CLI subcommand |
| **When to use** | You want a quick in-tool task management shortcut |
| **Example** | `/kallax-task list` or `/kallax-task claim TICKET-123` |
| **Role required** | None |
| **Related** | `/kallax-claim`, `/kallax-submit-pr` |
| **Source** | `.claude/commands/kallax-task.sh` |

---

## Appendix A: --help Flag (All 26 commands)

Every slash command supports `--help` / `-h` for in-tool quick reference:

```bash
/kallax-ask --help
```

Output format (consistent across all 26 commands):

```
<command> — <one-line description>

USAGE:
  /<command> [args]

ARGS:
  <arg1>           <description>
  <arg2>           <description>

DESCRIPTION:
  <2-3 line detailed description>

EXAMPLES:
  /<command> <example 1>
  /<command> <example 2>

RELATED:
  /<related-cmd-1>, /<related-cmd-2>
```

---

## Appendix B: Cross-Tool Compatibility (v2.0.6 4 工具 multi-tool)

跟 KALLAX-GLOSSARY §8.6-8.10,配合, all 26 slash commands are mirrored across 4 tools:

| Tool | Path | Format | Invocation |
|---|---|---|---|
| Claude Code | `.claude/commands/` | `.sh` (executable) | `/kallax-ask "..."` |
| opencode | `.opencode/command/` | `.md` (frontmatter + bash) | `/kallax-ask "..."` |
| Codex | `~/.codex/prompts/` | `.md` | `/kallax-ask "..."` |
| Gemini | `~/.gemini/commands/` | `.md` | `/kallax-ask "..."` |

**Naming 同类症状**: opencode uses `command/` (singular!) — see [KALLAX-GLOSSARY.md §8.7](../KALLAX-GLOSSARY.md#87-skillscommands-paths4-工具-路径映射-skillscommands-path-mapping).

**Auto-detect priority** (跟 `install.sh --target=auto`,配合): `claude` > `opencode` > `codex` > `gemini`.

---

## Appendix C: Related Documentation

- [cli-reference.md](cli-reference.md) — 12 CLI commands (`kallax task claim`, `kallax conductor heartbeat`, etc.)
- [INSTALL-MULTI-TOOL.md](../guides/INSTALL-MULTI-TOOL.md) — 4-tool install guide (v2.0.6+)
- [KALLAX-GLOSSARY.md](../KALLAX-GLOSSARY.md) — 39 terms (8.6-8.10 multi-tool,配合)
- [AGENTS.md](../../AGENTS.md) — Role definitions + hard rules
- [PROCESS.md](../../PROCESS.md) — Master 不能自己升级红线 (跟"独立" 拍 explicit,配合)

---

**跟决策者 2026-06-17 'C' explicit 派单,配合 (跟'独立' 拍板 explicit,配合, 跟 PROCESS.md:25-26,配合)**
**配合 v2.0.6 4 工具 multi-tool,配合 (跟 INSTALL-MULTI-TOOL.md §1.1 同类症状从根源修复段 互链)**
**跟 KALLAX-GLOSSARY §8.6-8.10,配合 (4 工具术语 SoT)**
**跟"翻篇&精进" 战略 一致 (0 增命令 0 增 Rule, 文档补全不引入新功能)**
