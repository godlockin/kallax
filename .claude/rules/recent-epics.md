---
paths:
  - CLAUDE.md
---

# Recent EPICs (v3.32.2 → v3.34.6, 主公 2026-08-08 拍板)

> **Path-scoped rule**: 只在 CLAUDE.md 修改时加载 (跟 EPIC-209 trim 联合).
> **来源**: 24 EPICs 累计 (19 v3.32.2-23 + 5 EPIC-203-208).

## 1. v3.32.2 → v3.32.23 (19 EPICs, 主公 2026-08-02/03/05 拍板)

| EPIC | Version | 关键 | 工具 / 文件 |
|------|---------|------|-----------|
| EPIC-157 | v3.32.2 | ticket.json 4 expert binding 字段 + mis_dispatch_binding_rate 北极星打通 | `scripts/binding/binding-tracker.sh`, `sprint-metrics.sh` |
| EPIC-158 | v3.32.3 | Forbidden Patterns regex false-positive + sqlite skipIf (CI debt) | `.github/workflows/ci.yml`, `skipIfNoSqlite` |
| EPIC-159 | v3.32.4 | CLAUDE.md 307→160 行 + `.claude/rules/*.md` path-scoped lazy load | `.claude/rules/{state-json,testing,branch-flow,strict-tsconfig}.md` |
| EPIC-160 | v3.32.5 | install.sh Omnibus — 全部件 deploy + `--inventory`/`--update`/3 skip flag | `scripts/install.sh`, 95 files |
| EPIC-161 | v3.32.6 | retrospective-routine.sh 6 阶段 routine (复盘/整理/review/升级/归档/删除) | `scripts/retrospective-routine.sh`, `--json` |
| EPIC-168-F | v3.32.13 | daemon 真跑验证 — 抓 3 真 bug (review 漏抓) | `tests/integration/heartbeat-daemon-runtime.test.sh` (10/16 → 抓 3 bug) |
| EPIC-168-BG | v3.32.14 | 修 EPIC-166 4 真 bug + 建北极星 dashboard | `heartbeat-daemon.sh`, `scheduler-hint.sh`, `run-history.sh`, `dashboard-metrics.sh`, `dashboard-metrics.html` |
| EPIC-169 | v3.32.15 | 公开化路径: README.en + frontstage + Lark/WeChat 群 | `README.en.md`, `web/showcase/`, `docs/community/`, `docs/sponsor/` |
| EPIC-170 | v3.32.16 | Expert plugin complete — enabled_policy + activation gates (9 expert 1:1 loopx) | `scripts/skill/skill-manager.sh`, `scripts/skill/skill-policy.sh` |
| EPIC-171 | v3.32.17 | 战略沉淀 — 3 视角 (PR+CTO+Marketing) 定位文档 + README "Why vs Claude Code?" | `confluence/research/kallax-positioning-2026-08-05.md`, `README.md` |
| EPIC-172 | v3.32.18 | 公开化协同 — Lark/WeChat 群 + hosted frontstage + growth loop | `docs/community/`, `web/showcase/`, `confluence/research/kallax-growth-loop-2026-08-05.md` |
| EPIC-175 | v3.32.21 | Security Rules 强化 — Release Capability Usage Gate + Contributor Attribution + Capability Placement 决策树 | `scripts/check-release-capability.sh`, `scripts/automation-monitor-todos.sh`, `scripts/check-benchmark-smoke.sh`, `docs/reference/capability-placement.md`, `docs/process/projection-sink-design.md` |
| EPIC-176 | v3.32.23 | Commit Hygiene 备案 + 未来指南 (跟 EPIC-155 1:1 pattern) | `confluence/decisions/commit-hygiene-2026-08-05.md`, `docs/reference/commit-hygiene-pattern-2026-08-05.md` |
| EPIC-177-G | v3.33.0 | run-history emit integration — 6 脚本 emit hook 闭环 4 北极星 | `binding-tracker.sh`, `heartbeat-daemon.sh`, `post-process.sh`, `branch-4pr.sh`, `install.sh`, `skill-manager.sh` |
| EPIC-180-A | v3.33.2 | frame-task.sh — 4 档路由 (TRIVIAL/SIMPLE/MEDIUM/COMPLEX) + 9 类破坏性拦 + FRAME 表单 | `scripts/frame-task.sh`, `.claude/skills/kallax/lib/frame-prompt.md`, `tests/integration/frame-task.test.sh` |
| EPIC-181 | v3.33.2 | 4-PR wrapper 硬化 R1-R5 — `--epic` 必填 + base 同步校验 + state 验证 + 默认删 branch + 退出码契约 0/1/2/3 | `scripts/branch-4pr.sh`, `tests/integration/branch-4pr-harden.test.sh` |
| EPIC-182 | v3.33.4 | 4-PR 实战回归 28 用例 (wrapper R1-R5 + Check 2.7 + branch allowlist + 9 类 + frame preamble) | `tests/integration/4pr-regression.test.sh` |
| EPIC-183 | v3.33.5 | release-entry.sh CHANGELOG 自动生成 + emit decision (跟 EPIC-177-G 联合) | `scripts/release-entry.sh`, `tests/integration/release-entry.test.sh` |
| EPIC-184 | v3.33.6 | frame-task multi-turn clarify (partial/answer/complete) — COMPLEX 档多轮主公澄清 | `scripts/frame-task.sh`, `tests/integration/multi-turn-clarify.test.sh` |
| EPIC-185 | v3.33.7 | 8 subagent 并行派单实测 (frame-task + emit + ledger 跨 agent 查询) | `tests/integration/multi-agent-dispatch.test.sh` |
| EPIC-186 | v3.33.8 | frame-llm.sh LLM v2 入口 + claude-haiku prompt 模板 (跟 heuristic 1:1 兼容) | `scripts/frame-llm.sh`, `tests/integration/frame-llm.test.sh` |
| EPIC-187 | v3.33.9 | AUTO-PERMS 扩展 — git fetch/pull/log/diff 等 read-only 命令默认通过 | `.claude/skills/kallax/SKILL.md`, `.claude/skills/kallax/lib/frame-prompt.md`, `tests/integration/auto-perms-expand.test.sh` |

## 2. 2026-08-08 sprint (5 EPICs, 主公拍板)

| EPIC | Version | 关键 | 工具 / 文件 |
|------|---------|------|-----------|
| EPIC-203 | (审计) | 4-expert 26 项审计闭环 (11 FIXED + 4 FALSE POSITIVE + 11 NO-OP) | `confluence/decisions/EPIC-203-audit-retrospective-2026-08-08.md` |
| EPIC-204 | (sprint-metrics) | docs-only metrics 适配 (`--docs-only` flag + exit 3 DOCS_ONLY_SKIP) | `scripts/metrics/sprint-metrics.sh`, `tests/integration/epic-204-docs-only-metrics-test.sh` |
| EPIC-205 | (retrospective) | retrospective-routine.sh 6 阶段季度 dry-run + KALLAX_ROOT worktree-safe fix | `scripts/retrospective-routine.sh`, `confluence/decisions/EPIC-205-retrospective-routine-2026-08-08.md` |
| EPIC-206 | (manifesto) | 战略文档归一 5 文件 (TOP-DESIGN / SCOPE-MISSION-VISION / TIMELINE / LESSONS / BEST-PRACTICES) | `confluence/manifesto/`, `docs/ARCHITECTURE.md` (DEPRECATED redirect) |
| EPIC-207 | (governance) | 4-PR master review 强制 + 0 force-push bypass (除 EPIC-155/176 备案), PR-2 v2 修正: FF push + comment 验证 | `CLAUDE.md §4`, `confluence/decisions/EPIC-207-4pr-governance-2026-08-08.md` |
| EPIC-208 | (governance-debt) | 治理债闭环 — PR-2 v2 doc 落地 + force-push 备案债 4 commits 补录 (跟 EPIC-155/176 1:1) | `confluence/decisions/EPIC-207-4pr-governance-2026-08-08.md §5.1-5.2` |
| EPIC-209 | (sprint-close) | Sprint 闭环 — CLAUDE.md trim + retrospective --apply + recent-epics lazy-load | `CLAUDE.md §6`, `.claude/rules/recent-epics.md` |

## 3. 累计统计 (跟 EPIC-159 + EPIC-205 1:1)

- **总 EPIC**: 24 (19 v3.32.2-23 + 5 EPIC-203-208)
- **总 commit**: 8 release 累计 (跟 EPIC-206 03-timeline.md 1:1)
- **0 增 Rule, 0 增 immutable script, 0 改 source code** (跟 EPIC-197/199/200/201/202-A/B/C/203-208 docs-only EPIC 1:1)
- **0 force-push bypass** (除 EPIC-155/176 备案, 跟 EPIC-207 + EPIC-208 §5.2 1:1)

## 4. Reference

- [CLAUDE.md §6](../../CLAUDE.md) — lazy-load 入口
- [confluence/manifesto/03-timeline.md](../../confluence/manifesto/03-timeline.md) — 高阶时间线
- [confluence/manifesto/04-lessons.md](../../confluence/manifesto/04-lessons.md) — 经验教训索引
- [CHANGELOG.md](../../CHANGELOG.md) — raw release 节点