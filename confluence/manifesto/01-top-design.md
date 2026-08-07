# KALLAX 顶层设计 (Top Design)

> **SoT**: 跟 docs/ARCHITECTURE.md (v3.0.0 时代, 467 行) 1:1 归并, 内容已部分迁移
> **当前版本**: v3.34.6 (miao HEAD, 2026-08-08)
> **作者**: master | **审核**: 主公 2026-08-08 拍板 (EPIC-206)

## 1. 一句话定位

KALLAX = **生产级 Claude Code 治理框架**, 借鉴 eket 极简哲学, 通过 Rules + immutable scripts + 4-PR 流程 + 4 北极星指标, 让 Claude Code 从"被动工具"升级为"受治理的工程团队成员".

## 2. 4 大子系统

```
┌─────────────────────────────────────────────────────────────┐
│                    KALLAX v3.34.6 顶层架构                    │
├─────────────────────────────────────────────────────────────┤
│  1. CLAUDE.md 治理 2.0 (EPIC-159)                            │
│     - 主文件 ≤ 200 行 (Anthropic 硬阈值)                     │
│     - 6 条 Rule (§1-5 + §9) 必读 + lazy-load path-scoped     │
│     - .claude/rules/*.md 按 file path 自动加载              │
├─────────────────────────────────────────────────────────────┤
│  2. 5 不可更改法律 (immutable scripts)                       │
│     - scripts/verify/check-{decorative,narrative,fail-closed,self-heal}.sh │
│     - scripts/hooks/check-claim-evidence.sh (pre-commit)    │
│     - 退出码契约 0=PASS / 1=FAIL / 2=BLOCKED-env             │
├─────────────────────────────────────────────────────────────┤
│  3. 4-PR 工作流 (EPIC-074 + EPIC-181 + EPIC-182 实战回归)   │
│     feature/* → testing → main → miao                       │
│     4 阶段 × 5 验证站 (L1-L5 5-Level Verify)                │
├─────────────────────────────────────────────────────────────┤
│  4. 4 北极星指标 (EPIC-023-C + EPIC-194 Rule 36 + EPIC-204)  │
│     expert_activation ≥5 | cross_epic_reuse ≥60%             │
│     ab_hit_mismatch <15% | mis_dispatch <10%                 │
│     docs-only EPIC: --docs-only flag + exit 3                │
└─────────────────────────────────────────────────────────────┘
```

## 3. 36 条 Rule 治理框架 (v3.34.6)

| Rule | 来源 | 用途 |
|------|------|------|
| §1 CLI 执行规范 | EPIC-026-A | 后台跑 + log 到 /tmp + check exit + 自动 tail + 禁监控 |
| §2 5-Level Verify | EPIC-069-D | L1 git / L2 stdout / L3 4-expert / L4 independent / L5 boundary |
| §3 Rule 34 | EPIC-152 | Bugfix ticket 必带 3 字段 (reproduction_command/exit/raw_output) |
| §3.1 Rule 35 | EPIC-190 | Sprint 时间盒 ≤ 5 EPIC, ≤ 10 commits, ≤ 500 行 |
| §3.2 Rule 36 | EPIC-194 + EPIC-204 | Sprint 必跑 4 北极星 + docs-only 跳过 |
| §4 4-branch flow | EPIC-074 | feature → testing → main → miao 强制 |
| §5 immutable scripts | EPIC-069-D | 5 verify + 1 hook = 6 immutable |
| §6 Recent EPICs | v3.32.2-23 | 19 EPIC 累计 (157-187) |

## 4. 4 sub-agent 协作模式 (EPIC-056-A)

| 模式 | 触发 | 验证 |
|------|------|------|
| Conductor | 全局扫描 | 1 份报告, 0 协调开销 |
| 4 default | Backend/Frontend/UX/Product | 4 份并行 |
| 5 extended | security/process/auditor/compliance/decision-gate | 5 份并行 |
| Master 仲裁 + 主公拍板 | 9 份汇总 | P0 红线 / P1 备案 / P2 操作 |

## 5. 数据流 (跟 EPIC-185 8 subagent 实测 1:1)

```
主公诉求 (主公)
   ↓ frame-task.sh classify (4 档: TRIVIAL/SIMPLE/MEDIUM/COMPLEX)
frame-prompt.md 输出 FRAME 表单
   ↓ 9 类破坏性拦 (Rule 9 联合)
frame-llm.sh LLM v2 (claude-haiku)
   ↓ emit decision → run-history.jsonl (EPIC-177-G)
binding-tracker.sh (EPIC-157 4 expert binding)
   ↓ state 落档 + post-process 11 步骤 (EPIC-059-E)
Sprint 闭环 (Rule 35)
   ↓ sprint-metrics.sh (Rule 36 + EPIC-204 --docs-only)
4 北极星指标 PASS / NO_DATA / DOCS_ONLY_SKIP
```

## 6. 跟 ARCHITECTURE.md 关系

| 维度 | docs/ARCHITECTURE.md (v3.0.0) | confluence/manifesto/01-top-design.md |
|------|-------------------------------|---------------------------------------|
| **版本** | v3.0.0 (2026-06 era) | v3.34.6 (current) |
| **行数** | 467 | ~150 |
| **关注** | 6 武器 + 25 cells + eket 对比 | 4 子系统 + 36 Rule + 4 北极星 |
| **状态** | 部分已迁移 (W3 sub-role → Rule 9; 5 levels → Rule 2) | 当前 truth |

**迁移路径**: 跟 EPIC-197/199/200/201 1:1 pattern, docs/ARCHITECTURE.md 加 DEPRECATED header, redirect 到本文.

## 7. Reference (跟 EPIC-205 6 阶段 跑批 1:1)

- [02-scope-mission-vision.md](02-scope-mission-vision.md) — 范围/使命/愿景/价值观
- [03-timeline.md](03-timeline.md) — 10 release 累积时间线
- [04-lessons.md](04-lessons.md) — 经验教训索引
- [05-best-practices.md](05-best-practices.md) — 最佳实践集
- [CLAUDE.md](../../CLAUDE.md) — cold start 入口 (3.3KB, 必读)
- [docs/process/doc-audit-flow.md](../../docs/process/doc-audit-flow.md) — 5 阶段审计流