# KALLAX 项目 Timeline — 立项 → v3.34.5

> **目的**: 单文件追溯 KALLAX 从立项到当前 miao HEAD `110bc153` 的全部大节点 + 功能增量。
> **范围**: v1.0 (2026-01) → v3.34.5 (2026-08-07, EPIC-194)。
> **数据源**: CHANGELOG.md + confluence/decisions/* + .claude-mem observations + git log origin/miao。
> **写入**: 2026-08-07, 跟 EPIC-194 Rule 36 联合 (Sprint 末沉淀)。

---

## 1. 立项期 (2026-01, v1.0-v1.2)

**触发**: 主公观察到 Claude Code 工具流单一 (单角色, 无 subagent 调度), 无法支撑多 EPIC 并行派单。

**核心产出**:
- v1.0 — KALLAX 1-role 单 Performer 跑通基础 lifecycle
- v1.2 — 加 4 sub-role (coder / reviewer / tester / docs), dispatch.sh 雏形
- 6 武器 — 5-Level Verify / 4-PR Flow / 决策矩阵 25 cells / 自动化监控 / sub-role / 跨 repo 协同

**借鉴**: eket MASTER-RULES.md §10 (4 步 → 11 步 Post-Process), §11 (7 项 → 11 项 dispatch checklist), 借方法论不借代码。

---

## 2. Phase 1 治理期 (2026-03 ~ 2026-05, v2.0-v2.5)

**触发**: 5 release 累计出现 7 BE (教训) — silent output / 卡死 / race condition / 派单错位。

**核心产出**:
- v2.0.3 — EPIC-056-A 3 阶段治理 (Conductor 全局扫 → 9 专家并行 → Master 仲裁), 净价值 62.5% → 65%
- v2.0.6 — BE-14 1 ticket 1 subagent 串行, 100% PASS deliver
- v2.3.0 — EPIC-023-C 北极星 4 指标 (expert_activation / cross_epic_reuse / ab_hit / mis_dispatch), 数据源 EPIC-021-F expert_invocations 队列
- v2.4.1 — Rule 合并反思 (18 release 累计 0 增 Rule)

**关键 Rule**:
- Rule 5 (DRY) — 单源真相, 跨 EPIC 复用 ≥60%
- Rule 8 (Rule-of-500) — 单 commit ≤ 500 行
- Rule 9 (KPI X/Y) — 报告必带 raw test output + X/Y 格式
- Rule 11 (5-Level Verify L1-L5)

---

## 3. 安全 + 工具固化期 (2026-06 ~ 2026-07, v2.6-v3.10)

**触发**: v3.8.0 假 PASS 危机 — README 宣称 "25/25 PASS / 生产级", 红蓝对抗实测 `cargo test` 11 errors + Node 8/19 fail。

**核心产出**:
- v3.8.1 — EPIC-069-D check-claim-evidence.sh (README/CHANGELOG 数字必带 raw test output)
- v3.9 — EPIC-026-A fail-fast (wrapper `set -e` + `trap ERR` + 禁 `cmd || true`)
- v3.10 — EPIC-074 4-branch 强制流程 (feature → testing → main → miao), 主公拍板 2026-07-09
- v3.10.1 — EPIC-127 /kallax 命令入口 1:1 映射 26 sub-command
- v3.15 — EPIC-119 OpenAI 3-Class tool taxonomy (data/action/orchestration)
- v3.20 — EPIC-131/132 tsconfig strict + scan-dead-code gate-paint 防御

**关键 Rule**:
- Rule 4 (4-PR 强制)
- Rule 13 (3 模式 decision-gate)
- Rule 18 (反模式黑名单)
- Rule 33 (decision-gate P0/P1/P2 分级)

---

## 4. 北极星 + 流程贯通期 (2026-07-30 ~ 2026-08-02, v3.32.x)

**核心产出**:
- v3.32.2 — EPIC-157 ticket.json 4 expert binding 字段 + mis_dispatch_binding_rate 北极星打通
- v3.32.3 — EPIC-158 Forbidden Patterns regex false-positive + sqlite skipIf (CI debt)
- v3.32.4 — EPIC-159 CLAUDE.md 307→160 行 + `.claude/rules/*.md` path-scoped lazy load (治理 2.0)
- v3.32.5 — EPIC-160 install.sh Omnibus (95 文件 deploy + 3 skip flag)
- v3.32.6 — EPIC-161 retrospective-routine.sh (6 阶段 routine)
- v3.32.13 — EPIC-168-F daemon 真跑验证 (10/16 → 抓 3 真 bug)
- v3.32.14 — EPIC-168-BG 修 EPIC-166 4 真 bug + 建北极星 dashboard
- v3.32.15 — EPIC-169 公开化路径 (README.en / frontstage / Lark / WeChat)
- v3.32.16 — EPIC-170 Expert plugin complete (enabled_policy + 9 expert 1:1 loopx)
- v3.32.17 — EPIC-171 战略沉淀 (3 视角 PR+CTO+Marketing)
- v3.32.18 — EPIC-172 公开化协同 (Lark/WeChat + hosted frontstage + growth loop)
- v3.32.21 — EPIC-175 Security Rules (Release Capability Usage Gate + Capability Placement)
- v3.32.23 — EPIC-176 Commit Hygiene 备案 (跟 EPIC-155 1:1 pattern)

---

## 5. 框架封装期 (2026-08-03 ~ 2026-08-07, v3.33.x → v3.34.5)

**核心产出**:
- v3.33.0 — EPIC-177-G run-history emit integration (6 脚本 emit hook 闭环 4 北极星)
- v3.33.2 — EPIC-180-A frame-task.sh (4 档路由 TRIVIAL/SIMPLE/MEDIUM/COMPLEX + 9 类破坏性硬拦 + FRAME 6 字段表单)
- v3.33.2 — EPIC-181 branch-4pr.sh 硬化 R1-R5 (`--epic` 必填 + base 同步校验 + state 验证 + 默认删 branch + 退出码 0/1/2/3)
- v3.33.4 — EPIC-182 4-PR 实战回归 28 用例
- v3.33.5 — EPIC-183 release-entry.sh CHANGELOG 自动生成 + emit decision
- v3.33.6 — EPIC-184 frame-task multi-turn clarify (partial/answer/complete)
- v3.33.7 — EPIC-185 8 subagent 并行派单实测
- v3.33.8 — EPIC-186 frame-llm.sh LLM v2 入口 (claude-haiku prompt, mock mode)
- v3.33.9 — EPIC-187 AUTO-PERMS 扩展 (git fetch/pull/log/diff + Read/ls/cat 默认通过)
- v3.34.2 — EPIC-190 Rule 35 Sprint 规划时间盒 (5 EPIC / 10 commits / 500 行 / 4-PR closure)
- v3.34.3 — EPIC-191 lint-fix shellcheck (删 KALLAX_ROOT + SCORE_SIMPLE_MIN + exit 引号)
- v3.34.4 — EPIC-193 frame-task --emit + emit-all (集成 run-history)
- v3.34.5 — **EPIC-194 Rule 36 Sprint 结束必跑 4 北极星 metric** (当前 miao HEAD)

---

## 6. 累计 KPI

| 维度 | 立项 (v1.0) | 当前 (v3.34.5) |
|------|-------------|----------------|
| 角色 | 1 role | 4 sub-role + 9 expert + 5 extended |
| 阶段 | 1 stage | 3 阶段治理 (Conductor / 9 expert / Master) |
| Rule 数 | 0 | 36 Rule (含 Rule 34/35/36) |
| Immutable scripts | 0 | 5 (check-decorative / check-narrative / check-fail-closed / check-self-heal / check-claim-evidence) |
| 北极星指标 | 0 | 4 (expert_activation / cross_epic_reuse / ab_hit / mis_dispatch) |
| PR 流程 | 单 push | 4-PR (feature → testing → main → miao) |
| 框架入口 | 0 | /kallax 26 sub-command + frame-task 4 档 |
| CLAUDE.md 行数 | — | 197 (≤200 硬阈值, 治理 2.0) |
| 测试套件 | 0 | 15 suites, 218 / 218 PASS |
| Sprint 闭环 | 无 | Rule 35 timebox + Rule 36 4 metric |

---

## 7. 关键里程碑节点

| 日期 | 节点 | 关键 |
|------|------|------|
| 2026-01 | 立项 | v1.0 跑通 |
| 2026-03-15 | EPIC-056-A | 3 阶段治理 |
| 2026-05-20 | v3.8.0 假 PASS 危机 | 红蓝对抗抓出 11 cargo errors + 8 Node fail |
| 2026-06-07 | EPIC-023-C | 4 北极星 metric 落地 |
| 2026-07-09 | EPIC-074 | 4-branch 强制 (主公拍板) |
| 2026-08-02 | EPIC-159 | CLAUDE.md 治理 2.0 (160 行硬阈值) |
| 2026-08-03 | EPIC-180-A | frame-task 4 档路由 |
| 2026-08-07 | EPIC-194 | Rule 36 Sprint 4 metric (当前) |

---

## 8. 当前 Sprint 状态 (2026-08-07)

- **当前 EPIC**: EPIC-195 (0 source change 备案)
- **miao HEAD**: `110bc153` (v3.34.5)
- **下一个方向**: 待主公拍板

---

> **引用**: CHANGELOG.md / CLAUDE.md / confluence/decisions/* / .claude-mem observations (13 EPIC, 26k tokens 历史).
> **联动**: EPIC-194 Rule 36 (Sprint 末必跑 4 metric) + EPIC-188 retrospective (6 阶段 routine).
