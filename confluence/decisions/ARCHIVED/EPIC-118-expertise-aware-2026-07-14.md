# EPIC-118 — Expertise-aware Dispatch (Anthropic Claude Code Research 借鉴)

> Date: 2026-07-14 | 3 tickets (A/B/C) | Anthropic research ref

## 起源

主公 2026-07-14 研究 Anthropic Claude Code Research 后 explicit "需要"。

**Anthropic 核心数据**:

| Metric | Novice | Expert |
|--------|--------|--------|
| Verified success rate | 15% | 28-33% |
| Abandonment rate | 19% | 5-7% |
| Actions/prompt | ~5 | ~12 |

**关键洞察**:
1. **Abandonment tracking** 是核心 reliability 指标
2. **Verified success = judged + hard evidence** (git commits, PRs, tests)
3. **Expertise-aware autonomy** — expert performer 需要更少 checkpoints

## KALLAX 现状 vs 目标

| 维度 | 现状 | 目标 |
|------|------|------|
| Performer expertise | 无分层, 同等待遇 | L1/L2/L3 mastery |
| Dispatch awareness | 随机派单 | 考虑 mastery |
| Abandonment | 未跟踪 | 主动上报 |
| Success evidence | ticket.json status | + verified_commit_sha |

## 3 Ticket

| Ticket | 主题 | 关键文件 | Acceptance |
|--------|------|---------|-----------|
| **A** | abandonment_rate 指标 | scripts/metrics/lib/metrics.sh | 新 metric, target <10% |
| **B** | schema: mastery_level + verified_commit_sha | docs/ticket-schema.md | 新字段 + 文档 |
| **C** | expertise-aware dispatch | node/src/core/task-assigner.ts | L1/L2/L3 差异化 checkpoints |

## Anthropic 原文

```
Verified Success Definition: Requires BOTH judged success AND hard evidence
Error recovery: experts succeed 4x more often after hitting trouble
Abandonment: 19% novice vs 5-7% expert
```

## 联动

- EPIC-117 (Simplicity — 不要借复杂度之名堆规则)
- EPIC-023-C (sprint metrics 北极星指标)
- EPIC-056-A (3 阶段治理)
