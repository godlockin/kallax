---
paths:
  - CLAUDE.md
---

# Recent EPICs (v3.32.2 → v3.34.7, 主公 2026-08-09 拍板)

> **Path-scoped rule**: 只在 CLAUDE.md 修改时加载 (跟 EPIC-209 trim 一起).
> **来源**: 44 EPICs 累计 (19 v3.32.2-23 + 5 EPIC-203-208 + 20 EPIC-210-229).

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
| EPIC-170 | v3.32.16 | Expert plugin complete — enabled_policy + activation gates (9 expert 对齐 loopx) | `scripts/skill/skill-manager.sh`, `scripts/skill/skill-policy.sh` |
| EPIC-171 | v3.32.17 | 战略沉淀 — 3 视角 (PR+CTO+Marketing) 定位文档 + README "Why vs Claude Code?" | `confluence/research/kallax-positioning-2026-08-05.md`, `README.md` |
| EPIC-172 | v3.32.18 | 公开化协同 — Lark/WeChat 群 + hosted frontstage + growth loop | `docs/community/`, `web/showcase/`, `confluence/research/kallax-growth-loop-2026-08-05.md` |
| EPIC-175 | v3.32.21 | Security Rules 强化 — Release Capability Usage Gate + Contributor Attribution + Capability Placement 决策树 | `scripts/check-release-capability.sh`, `scripts/automation-monitor-todos.sh`, `scripts/check-benchmark-smoke.sh`, `docs/reference/capability-placement.md`, `docs/process/projection-sink-design.md` |
| EPIC-176 | v3.32.23 | Commit Hygiene 备案 + 未来指南 (同 EPIC-155 pattern) | `confluence/decisions/commit-hygiene-2026-08-05.md`, `docs/reference/commit-hygiene-pattern-2026-08-05.md` |
| EPIC-177-G | v3.33.0 | run-history emit integration — 6 脚本 emit hook 打通 4 北极星 | `binding-tracker.sh`, `heartbeat-daemon.sh`, `post-process.sh`, `branch-4pr.sh`, `install.sh`, `skill-manager.sh` |
| EPIC-180-A | v3.33.2 | frame-task.sh — 4 档路由 (TRIVIAL/SIMPLE/MEDIUM/COMPLEX) + 9 类破坏性拦 + FRAME 表单 | `scripts/frame-task.sh`, `.claude/skills/kallax/lib/frame-prompt.md`, `tests/integration/frame-task.test.sh` |
| EPIC-181 | v3.33.2 | 4-PR wrapper 硬化 R1-R5 — `--epic` 必填 + base 同步校验 + state 验证 + 默认删 branch + 退出码契约 0/1/2/3 | `scripts/branch-4pr.sh`, `tests/integration/branch-4pr-harden.test.sh` |
| EPIC-182 | v3.33.4 | 4-PR 实战回归 28 用例 (wrapper R1-R5 + Check 2.7 + branch allowlist + 9 类 + frame preamble) | `tests/integration/4pr-regression.test.sh` |
| EPIC-183 | v3.33.5 | release-entry.sh CHANGELOG 自动生成 + emit decision (接 EPIC-177-G) | `scripts/release-entry.sh`, `tests/integration/release-entry.test.sh` |
| EPIC-184 | v3.33.6 | frame-task multi-turn clarify (partial/answer/complete) — COMPLEX 档多轮主公澄清 | `scripts/frame-task.sh`, `tests/integration/multi-turn-clarify.test.sh` |
| EPIC-185 | v3.33.7 | 8 subagent 并行派单实测 (frame-task + emit + ledger 跨 agent 查询) | `tests/integration/multi-agent-dispatch.test.sh` |
| EPIC-186 | v3.33.8 | frame-llm.sh LLM v2 入口 + claude-haiku prompt 模板 (兼容 heuristic) | `scripts/frame-llm.sh`, `tests/integration/frame-llm.test.sh` |
| EPIC-187 | v3.33.9 | AUTO-PERMS 扩展 — git fetch/pull/log/diff 等 read-only 命令默认通过 | `.claude/skills/kallax/SKILL.md`, `.claude/skills/kallax/lib/frame-prompt.md`, `tests/integration/auto-perms-expand.test.sh` |

## 2. 2026-08-08 sprint (5 EPICs, 主公拍板)

| EPIC | Version | 关键 | 工具 / 文件 |
|------|---------|------|-----------|
| EPIC-203 | (审计) | 4-expert 26 项审计完成 (11 FIXED + 4 FALSE POSITIVE + 11 NO-OP) | `confluence/decisions/EPIC-203-audit-retrospective-2026-08-08.md` |
| EPIC-204 | (sprint-metrics) | docs-only metrics 适配 (`--docs-only` flag + exit 3 DOCS_ONLY_SKIP) | `scripts/metrics/sprint-metrics.sh`, `tests/integration/epic-204-docs-only-metrics-test.sh` |
| EPIC-205 | (retrospective) | retrospective-routine.sh 6 阶段季度 dry-run + KALLAX_ROOT worktree-isolation fix | `scripts/retrospective-routine.sh`, `confluence/decisions/EPIC-205-retrospective-routine-2026-08-08.md` |
| EPIC-206 | (manifesto) | 战略文档归一 5 文件 (TOP-DESIGN / SCOPE-MISSION-VISION / TIMELINE / LESSONS / BEST-PRACTICES) | `confluence/manifesto/`, `docs/ARCHITECTURE.md` (DEPRECATED redirect) |
| EPIC-207 | (governance) | 4-PR master review 强制 + 0 force-push bypass (除 EPIC-155/176 备案), PR-2 v2 修正: FF push + comment 验证 | `CLAUDE.md §4`, `confluence/decisions/EPIC-207-4pr-governance-2026-08-08.md` |
| EPIC-208 | (governance-debt) | 治理债收口 — PR-2 v2 doc 落地 + force-push 备案债 4 commits 补录 (同 EPIC-155/176 处理) | `confluence/decisions/EPIC-207-4pr-governance-2026-08-08.md §5.1-5.2` |
| EPIC-209 | (sprint-close) | Sprint 收口 — CLAUDE.md trim + retrospective --apply + recent-epics lazy-load | `CLAUDE.md §6`, `.claude/rules/recent-epics.md` |

## 3. v3.34.7 (EPIC-210 → EPIC-229, 20 EPICs, 主公 2026-08-08/09 拍板)

> **来源**: prime-agent 调研 (EPIC-217~222) + 治理债收口 (EPIC-223~229)

### 3.1 CI 修复 (EPIC-210 / EPIC-211)

| EPIC | 关键 | 工具 / 文件 |
|------|------|-----------|
| EPIC-210 | cargo fmt --all + DCO sign-off 补录 | `rust/crates/kallax-engine/src/ticket_engine.rs` |
| EPIC-211 | Forbidden Patterns regex 排除注释行 + npm audit fix (406 packages) | `.github/workflows/ci.yml`, `node/package-lock.json` |

### 3.2 README / manifesto (EPIC-212 → EPIC-215)

| EPIC | 关键 | 工具 / 文件 |
|------|------|-----------|
| EPIC-212 | README top v3.0.0 → v3.34.6 | `README.md` |
| EPIC-213 | 一句话介绍 (中英双语) | `confluence/manifesto/00-elevator-pitch.md` |
| EPIC-214 | README 重整理 463 → 157 行 (删 3 重复 + 修 6 不准确) | `README.md` |
| EPIC-215 | 技术栈现状澄清 (Rust + Node active, Python 1 helper) | `confluence/manifesto/01-top-design.md §5.1` |

### 3.3 Rule 37 + prime-agent 调研 (EPIC-216 → EPIC-222)

| EPIC | 关键 | 工具 / 文件 |
|------|------|-----------|
| EPIC-216 | Rule 37 小 effort auto-approve (override EPIC-207 §1) | `CLAUDE.md §6.4`, `.claude/rules/rule-37.md` |
| EPIC-217 | README 30s elevator + When-to-use 场景段 | `README.md` |
| EPIC-218 | heartbeat-conductor.sh 跨 worktree 状态聚合 | `scripts/heartbeat-conductor.sh`, `.claude/skills/kallax/SKILL.md` |
| EPIC-219 | snapshot-claude-md.sh — CLAUDE.md 改前 git tag + rollback | `scripts/verify/snapshot-claude-md.sh` |
| EPIC-220 | check-disclaimer.sh — 反向 disclaimer audit (借 prime-agent "limit ≠ success") | `scripts/verify/check-disclaimer.sh` |
| EPIC-221 | DCO commitlint + Rule 34 reproduction 3 字段门控 | `commitlint.config.js`, `.github/PULL_REQUEST_TEMPLATE.md`, `CONTRIBUTING.md` |
| EPIC-222 | persistent-supervisor + capability policy 设计稿 (research-only, Q3 候选) | `confluence/decisions/EPIC-222-persistent-supervisor-2026-08-08.md` |

**调研源**: `confluence/decisions/prime-agent-research-2026-08-08.md` — PrimeIntellect-ai/prime-agent (6.9k stars) 3 阶段治理调研, 6 P1 EPIC 借鉴清单 + 6 项不借鉴 (含理由).

### 3.4 治理债收口 (EPIC-223 → EPIC-229)

| EPIC | 关键 | 工具 / 文件 |
|------|------|-----------|
| EPIC-223 | ticket 归档基线 (45 EPIC ≤ 222 不回溯) + CLAUDE.md 数字对齐 (4/5/6/7 → 统一) | `jira/tickets/.archive-baseline.json`, `scripts/verify/check-ticket-schema.sh`, `.claude/rules/immutable-scripts.md` |
| EPIC-224 | **hook 体系整体失效修复** — core.hooksPath 曾指向已删临时目录, 所有 gate 从未运行 | `scripts/hooks/install.sh` 重写, `scripts/hooks/commit-msg` 新建, CI `hook-health` job |
| EPIC-225 | jargon 黑名单 + gate (主公拍板禁黑话) — 4 类别 + baseline 划线 | `jira/tickets/.jargon-blacklist.json`, `scripts/verify/check-jargon.sh` |
| EPIC-226 | 3 个真 fire-and-forget 修复 + detector 4 bug (19 报告 → 3 真违规, 84% 误报) | `scripts/verify/check-self-heal.sh`, `scripts/audit/audit-log-sink.sh`, `scripts/io/{conflict-detect,file-lock}.sh` |
| EPIC-227 | worktree pre-commit KALLAX_ROOT 改用 `git rev-parse --show-toplevel` | `scripts/hooks/pre-commit` (1 行) |
| EPIC-228 | 14 ticket 定性 (10 归档 done + 4 标 `_pending_master_review`) | `jira/tickets/EPIC-{150,154,157,158,159,160,171,172,174,177-G}/ticket.json` |
| EPIC-229 | testing 分支恢复 + 防复发 gate + 测试缺口分类 (18 → 真实 0) | `scripts/verify/check-branch-flow.sh`, CI `hook-health` step |

## 4. 累计统计

### 4.1 v3.32.2 → v3.34.6 (24 EPICs)

- **总 EPIC**: 24 (19 v3.32.2-23 + 5 EPIC-203-208)
- **0 增 Rule, 0 增 immutable script, 0 改 source code** (EPIC-197/199/200/201/202-A/B/C/203-208 均 docs-only)
- **0 force-push bypass** (除 EPIC-155/176 备案)

### 4.2 v3.34.7 (EPIC-210 → EPIC-229, 20 EPICs)

- **immutable scripts**: 5 → 9 (EPIC-219 snapshot + EPIC-220 disclaimer + EPIC-223 ticket-schema + EPIC-225 jargon)
- **Rule 数**: 36 → 37 (EPIC-216 Rule 37 小 effort auto-approve)
- **新 gate**: `check-branch-flow.sh` (运维检查, 不计入 immutable)
- **CI job 新增**: `hook-health` (EPIC-224) + 4-branch flow step (EPIC-229)
- **baseline 机制** 3 处: ticket 归档 (EPIC-223) / jargon (EPIC-225) / disclaimer (EPIC-229)
- **备案债**: EPIC-218~228 跳过 testing 阶段 (testing 分支曾被 `--delete-branch` 删除, EPIC-229 恢复)

### 4.3 本轮 3 个治理体系失效发现

| # | 失效 | 发现 EPIC | 影响面 |
|---|------|----------|--------|
| 1 | `core.hooksPath` 指向已删临时目录 → 所有 pre-commit gate 从未运行 | EPIC-224 | 2026-07-20 → 2026-08-08 共 272 commits 无 gate |
| 2 | `pre-push` `GIT_PUSH_OPTION_COUNT` unbound → push 静默失败 | EPIC-224 | hook 激活后立即暴露 |
| 3 | `KALLAX_ROOT` 硬编码 → worktree 内改动 hook 检测不到 | EPIC-227 | EPIC-226 实施时暴露 |

## 5. Reference

- [CLAUDE.md §6](../../CLAUDE.md) — lazy-load 入口
- [confluence/manifesto/03-timeline.md](../../confluence/manifesto/03-timeline.md) — 高阶时间线
- [confluence/manifesto/04-lessons.md](../../confluence/manifesto/04-lessons.md) — 经验教训索引
- [CHANGELOG.md](../../CHANGELOG.md) — raw release 节点
- [.claude/rules/immutable-scripts.md](immutable-scripts.md) — 9 immutable 清单 + 改数字流程
- [confluence/decisions/prime-agent-research-2026-08-08.md](../../confluence/decisions/prime-agent-research-2026-08-08.md) — 外部调研源

## EPIC-157 / 158 / 160 (从 CLAUDE.md §6.4 移出, EPIC-270)

> 起因: CLAUDE.md 加 EPIC-270 review 分级后超 200 行硬阈值.
> 这 3 段是 EPIC-209 trim 时漏掉的历史 EPIC 详情, 本该在这个文件.

**EPIC-157 binding tracking (v3.32.2+)** — Rule 36 北极星 #4 数据源: ticket.json `expert_binding.{suggested_expert,actual_expert,expert_binding_at,binding_change_reason}` 4 字段, Master 拆卡建议 → Performer claim 实际 → 偏离必填 reason. Metric: `scripts/metrics/lib/metrics.sh:compute_mis_dispatch_binding_rate`. 历史 ticket 无 binding 跳过, 不计入分母.
**EPIC-158 CI debt fix (v3.32.3+)** — `.github/workflows/kallax-ci.yml` Forbidden Patterns regex 排除 JSDoc prose (`@ts-ignore` / `:\s*any` / `TODO` 等在 JSDoc `^\s*\*` 行豁免) + `node/tests/expert-invocations-queue.test.ts:120` 5 sqlite 依赖 `it` → `skipIfNoSqlite` (CI 无 sqlite 自动 skip). 5/5 ci-debt-fix.test.sh PASS, 0 改 source code, 跟 EPIC-114 test 反模式 + BE-14 串行.
**EPIC-160 install.sh Omnibus (v3.32.5+)** — `scripts/install.sh` 全部件 deploy + `--inventory`/`--update`/3 skip flag, 95 files 覆盖. `--update` symlink mode 不破 user files, re-run idempotent (13/13). Ref: `.claude/rules/installation.md`.
