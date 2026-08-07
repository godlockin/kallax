# KALLAX 经验教训 (Lessons Index)

> **SoT**: `confluence/memory/lessons/` (跟 EPIC-023-A lessons-lookup 联合), 本文档是索引
> **作者**: master | **审核**: 主公 2026-08-08 (EPIC-206)

## 1. 教训分类 (跟 EPIC-023-A 1:1)

### A 类 — 治理债 (跟 Rule 2 + Rule 5 联合)

| 教训 | 来源 | 影响 |
|------|------|------|
| v3.8.0 "25/25 假 PASS" | EPIC-069-D | 5-Level Verify 强化 (L1-L5) |
| v3.8.0 form-only PASS | EPIC-102 | workspace 全跑 (`--workspace` 字面) |
| v3.30.0/1 canary 7 EPIC 误诊 | EPIC-152 (Rule 34) | Bugfix ticket 必带 reproduction 3 字段 |
| EPIC-198 docs-only CI exempt | EPIC-198 | docs-only PR 跳过 CI 检查 |
| EPIC-203 retrospective 4 false positive | EPIC-203 | Auditor 报告必 ground truth 验证 |

### B 类 — 流程债 (跟 Rule 4 + Rule 35 联合)

| 教训 | 来源 | 影响 |
|------|------|------|
| 4-branch bypass 历史债 | EPIC-155 + EPIC-176 (5 commits) | 备案 + Q3 2026 retractively re-promote |
| Testing/Main sync force-push | EPIC-142 + EPIC-146 | pattern 1:1 复用 |
| Commit Hygiene 备案 | EPIC-176 | docs/reference/commit-hygiene-pattern |
| Sprint 超大任务 | EPIC-190 (Rule 35) | ≤ 5 EPIC, ≤ 10 commits, ≤ 500 行 |
| EPIC-185 8 subagent 并行 | EPIC-185 | frame-task + emit + ledger 闭环 |

### C 类 — 内容债 (跟 EPIC-197/199/200/201 SoT 归并 联合)

| 教训 | 来源 | 影响 |
|------|------|------|
| 264 .md 文件审计 | EPIC-196 | 5 阶段审计流固化 |
| 跨目录重复 9 对 | EPIC-197 | sha256sum 二次验证 |
| 22 DEPRECATED header | EPIC-201 | docs/_deprecated-index.md |
| 0 stale ref (98 refs) | EPIC-200/201 | check-internal-refs.cjs scope 扩 web/ |
| audit-flow 文档说 3 phase 实际 5 | EPIC-202-C | Architect 对抗式 review |

### D 类 — 工具债 (跟 EPIC-131/132 联合)

| 教训 | 来源 | 影响 |
|------|------|------|
| scan-dead-code false positive | EPIC-131 | tsconfig strict + gate-paint 防御 |
| vitest test leak | EPIC-114 | afterEach 清理 + unique IDs |
| sed/awk false PASS | EPIC-180-A | jq 替代 (frame-task.sh) |
| nohup & 是逃逸路径 | EPIC-026-A | 统一走 exec-task.sh wrapper |
| whisper-cpp 10 段失败 | CLAUDE.md §1 起源 | wrapper 必 set -e + trap ERR |

### E 类 — 文化债 (跟价值观 1-5 联合)

| 教训 | 来源 | 影响 |
|------|------|------|
| 装饰性宣称 (生产级 / 治根) | EPIC-069-D | check-decorative-claim.sh + Rule 2 |
| narrative 包装 | EPIC-069-D | check-narrative.sh |
| fail-open (print FAIL + exit 0) | EPIC-069-D | check-fail-closed.sh |
| 估数 (1.5-2x / 100% parity) | EPIC-198 + EPIC-203 | 0 估数字 (跟 check-claim-evidence 联合) |
| 元层自嘲 | EPIC-171 | 数据说话, 0 自我怀疑暴露 |

## 2. 教训-EPIC 索引 (cross-reference)

| 教训类型 | EPIC 来源 | 当前状态 |
|---------|----------|---------|
| 5-Level Verify 强化 | EPIC-069-D | ✅ active (Rule 2) |
| Bugfix 独立复现 | EPIC-152 | ✅ active (Rule 34) |
| Sprint 时间盒 | EPIC-190 | ✅ active (Rule 35) |
| 4 北极星 | EPIC-194 + EPIC-204 | ✅ active (Rule 36 + --docs-only) |
| docs-only CI exempt | EPIC-198 | ✅ active |
| 5-Phase audit flow | EPIC-196/197/199/200/201 | ✅ active (docs/process/doc-audit-flow.md) |
| Retrospective Routine | EPIC-161 + EPIC-205 | ✅ active (6 阶段) |
| 4-PR 流程硬化 | EPIC-074 + EPIC-181/182 | ✅ active |

## 3. 教训查询

```bash
# 全文搜索 (跟 EPIC-023-A lessons-lookup 1:1)
python3 ~/.claude/lessons-lookup.py <keyword>

# 跨项目 lessons (主公 ~/.claude/CLAUDE.md 索引)
grep -r "关键词" ~/.claude/knowledge/
cat ~/.claude/knowledge/index.md
```

## 4. 教训 1:1 落地验证

| 教训 | 验证命令 |
|------|---------|
| 5-Level Verify | `bash scripts/check-claim-evidence.sh` |
| Bugfix 独立复现 | ticket.json `verification.reproduction_*` 3 字段 |
| Sprint 时间盒 | 4-PR 全闭环 + ≤ 500 行 commit |
| 4 北极星 | `bash scripts/metrics/sprint-metrics.sh --epic EPIC-XXX` |
| docs-only | `--docs-only` flag exit 3 |
| 5-Phase audit | `bash docs/process/doc-audit-flow.md` 引用 |
| Retrospective | `bash scripts/retrospective-routine.sh --dry-run` |
| 4-PR | `gh pr create --base testing` |

## Reference

- [confluence/memory/lessons/](../memory/lessons/) — 教训 raw 文件 (BE-28-29 / EPIC-016/022-A-B/040/062/064/065)
- [01-top-design.md](01-top-design.md) — 顶层设计
- [03-timeline.md](03-timeline.md) — 时间线
- [05-best-practices.md](05-best-practices.md) — 最佳实践
- [CLAUDE.md §3-3.2](../../CLAUDE.md) — Rule 34-36