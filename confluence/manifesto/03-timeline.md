# KALLAX 项目时间线 (Project Timeline)

> **SoT**: CHANGELOG.md 是 raw 节点 (跟 EPIC-205 跑批 1:1 验证 10 release); 本文档是高阶里程碑视图
> **作者**: master | **审核**: 主公 2026-08-08 (EPIC-206)

## 1. 2026-08-08 时间线 (当前 Sprint)

| 时间 | EPIC | Version | 主公拍板 | 关键产出 |
|------|------|---------|---------|---------|
| 08-08 | EPIC-203 | (审计) | "逐项核对 26 项挑刺" | 11 FIXED + 4 FALSE POSITIVE + 11 NO-OP |
| 08-08 | EPIC-204 | (sprint-metrics) | "docs-only 适配" | --docs-only flag + exit 3 + 8/8 TC |
| 08-08 | EPIC-205 | (retrospective) | "季度跑批" | KALLAX_ROOT fix + 6 stage inventory + 17/17 TC |
| 08-08 | EPIC-206 | (manifesto) | "战略文档归一" | 5 manifesto 文件 + SoT 归并 |

**Sprint 节奏** (跟 Rule 35 时间盒): 4 EPIC 全 4-PR 闭环, 0 跳流程, 0 跨 Sprint 累积.

## 2. 跨 8 release 累积 (v3.32 → v3.34)

| Date | Version | 主题 | 关键 EPIC |
|------|---------|------|-----------|
| 2026-08-05 | v3.32.15-23 | 公开化 + 安全强化 | EPIC-169/170/171/172/175/176 |
| 2026-08-05 | v3.33.0 | run-history emit + 北极星闭环 | EPIC-177-G |
| 2026-08-06 | v3.33.2 | frame-task + 4-PR 硬化 | EPIC-180-A/181 |
| 2026-08-07 | v3.33.4 | 4-PR 实战回归 + release-entry | EPIC-182/183 |
| 2026-08-07 | v3.33.6-9 | multi-turn clarify + LLM 入口 + AUTO-PERMS | EPIC-184/185/186/187 |
| 2026-08-07 | v3.34.0 | Sprint 时间盒 + Rule 35 | EPIC-190 |
| 2026-08-07 | v3.34.5 | 4 北极星 + Rule 36 | EPIC-194 |
| 2026-08-07 | v3.34.6 | docs-only metrics 适配 | EPIC-204 |

**8 release 累计**: 0 跳流程, 0 估数字, 0 装饰性宣称, 0 元层自嘲 (跟价值观 1:1).

## 3. EPIC 节奏可视化

```
v3.32.2 ──┐
          ├─ EPIC-157 (binding) ──┐
v3.32.6 ──┤                        │
          ├─ EPIC-161 (retro) ─────┤
v3.33.0 ──┤                        ├─ 19 EPIC / 4 月累计
          ├─ EPIC-177-G (emit) ────┤
v3.33.9 ──┤                        │
          ├─ EPIC-187 (AUTO-PERMS)─┤
v3.34.6 ──┤                        │
          ├─ EPIC-204 (docs-only) ─┘
          │
v3.34.6+ ─┴─ EPIC-206 (manifesto) ← 当前
```

## 4. 关键里程碑

| 节点 | 状态 | 描述 |
|------|------|------|
| **v3.32.0** (Q3 2026) | ✅ done | 38 docs 1:1 归档, EPIC-159 CLAUDE.md 治理 2.0 |
| **v3.34.0** (08-07) | ✅ done | Rule 35 Sprint 时间盒 (跟 EPIC-185 联合) |
| **v3.34.5** (08-07) | ✅ done | Rule 36 4 北极星 (跟 EPIC-194 联合) |
| **v3.34.6** (08-08) | ✅ done | docs-only metrics (跟 EPIC-204 联合) |
| **v3.35.0** (Q3 末) | 📋 planned | manifesto 落地 (EPIC-206, 当前) + 季度 retrospective 闭环 |
| **v3.40.0** (Q4 2026) | 📋 planned | 公开化路径完成 (Lark/WeChat + growth loop) |

## 5. 季度 retrospective (跟 EPIC-161 + EPIC-205 跑批 1:1)

最近季度跑批 (2026-08-08, EPIC-205):
- **retrospect**: 10 release (v3.34.6 → v3.32.15, 8 月份 8 release)
- **consolidate**: CLAUDE.md 197 行 (≤200 OK) + 0 duplicate
- **review-docs**: 6 path-scoped rules + 24 docs/reference + 65 decisions
- **upgrade**: node v24.15.0 + rustc 1.97.1 + install 97 files
- **archive**: 0 deprecated 新增 (跟 EPIC-199/200/201 22 entries 闭合)
- **delete**: 1 0-byte (web/dashboard-metrics.json) + scan-dead-code exit 2 BLOCKED-env

## 6. 未来时间线 (跟 Vision 1:1)

| 阶段 | 时间 | 关键 |
|------|------|------|
| **2026-Q3 末** | 09-30 | manifesto 落地 + retrospective 闭环 + docs-only 全 sprint 适配 |
| **2026-Q4** | 10-12 | 公开化路径完成 (Lark/WeChat 群 + hosted frontstage + growth loop, EPIC-169/172 闭环) |
| **2027-Q1** | 01-03 | 跨平台 0 适配 (保持 Claude Code 单一焦点, 拒绝 scope creep) |

## Reference

- [CHANGELOG.md](../../CHANGELOG.md) — raw release 节点
- [01-top-design.md](01-top-design.md) — 顶层设计
- [02-scope-mission-vision.md](02-scope-mission-vision.md) — 范围/使命/愿景/价值观
- [04-lessons.md](04-lessons.md) — 经验教训索引
- [scripts/retrospective-routine.sh](../../scripts/retrospective-routine.sh) — 6 阶段季度 routine