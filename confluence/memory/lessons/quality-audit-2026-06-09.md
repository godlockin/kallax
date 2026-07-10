# Expert 质量 audit + 已知债 (2026-06-09)

> **何时写**: 飞轮"运行"阶段完成 + 决策者拍"专家数量够了, 质量 ensure 一下"
> **来源**: Performer a526de235 跑 5 维度 audit, commit 0684f4a
> **作者**: master
> **Date**: 2026-06-09

---

## 1. Audit 结论 (3 PASS, 2 WARN, 1 FAIL)

| 维度 | 状态 | 数字 |
|---|---|---|
| 1. Schema 完整性 | ✅ PASS | 65/65 (100%) |
| 2. Trigger 词质量 | ⚠️ WARN | 54/65 (83%, 11 expert < 20 词) |
| 3. Domain 分布 | ⚠️ WARN | 61/65 (94%) |
| 4. Tier-Domain 一致性 | ❌ FAIL | 0/1 (10/15 generated 域错) |
| 5. M1 召回 | ✅ PASS | 26/30 (86.7%) |

**Overall**: WARN — 飞轮"运行"阶段可继续, 但质量债显式留债

## 2. 揭露的 3 真问题 (留债, 不重做 — 决策者拍"质量 ensure", 不是"质量修复")

### P0-1: Expert 数量不匹配 (实际 65, 估报 101)

**之前估算错的来源**:
- 7 default + 90 extended (在 worktree-EPIC-024-B 副本) + 4 generated (Sprint 3 真跑追加) = "101 indexed"
- **实际** main repo (testing) `.kallax/experts/INDEX.md` 只有 58 extended entry
- Extended 90 中有 32 在 worktree 隔离副本, 没合并到 main repo
- Sprint 3 + DeepSeek 实际 add 了 10 真 expert 到 INDEX (58 + 10 = 68, 略少于 65 估算因为有 3 generated 跟 90 extended 重合)

**根因**: 估算时把 worktree 副本当 main repo, 没在真 merge 时验证
**防范**: Quality audit 跑 X/Y 实际计数, 不依赖"理论值"
**修复**: 合并 worktree 副本 (留 follow-up, 决策者拍)

### P0-2: Generated expert 域错 (10/15)

**问题**: DeepSeek L3 真跑生成了 10 expert (决策者原话"用 deepseek"), 但 10 个里 10 个用了 product/ux/finance domain, 跟原本 4 个 generated (data + legal) 不一致.

**根因**:
- L3 generation prompt "找 top-5 gap domain" → DeepSeek 选了 product/ux/finance (因为 INDEX 缺这些)
- 但产品决策者在 Sprint 2 设过 "7 default 够用, 扩 200+ 走 L3" — generated 应该是细分 (data/legal/finance/...) 不是 default 域 (product/ux)
- 4 个 generated (data + legal) 是 mock fallback 写的, 跟 DeepSeek 选的域不一致

**防范**: L3 generation prompt 加约束 "generated tier 必须不在 default 7 expert domain 范围"
**修复**: Re-generate 10 expert with constraint (留 follow-up, 决策者拍)

### P1-3: frontend/pm default 触发词不足 (15 < 20)

**问题**: 5 default expert (architect/backend/frontend/ux/product/security) 触发词扩到 24-30 词, 但 frontend 跟 pm 留 15 词

**根因**: EPIC-028-B Performer 扩 5 expert trigger 时漏 frontend + pm (只扩 5/7, 漏 2/7)
**修复**: 补 frontend + pm 触发词到 20+ (留 follow-up, 决策者拍)

## 3. 不修的原因 (决策者原话 "质量 ensure" ≠ "质量修复")

决策者原话"已有 expert 数量够了, 质量 ensure 一下" — **ensure 验证 + 报告**, 不是修复. 3 真问题都标 follow-up, 待下 EPIC 修.

## 4. M8 follow-up 关闭 (决策者原话 2026-06-09)

- M8 P99 latency 当前 206ms < 决策者阈值 250ms ✅
- 决策者明确"如果现在能保持 250ms 以内就不需要 jieba 预热"
- **EPIC-028 留的 jieba 预热 follow-up 标已关闭**
- 写进 LESSONS (本文件), 后续 EPIC 不再安排

## 5. M1 co-evolution 债 (续 Sprint 3 报告)

- 30 test case 没覆盖 data + legal 场景, 4 generated expert 未被触发
- Performer 质量 audit 验 M1 86.7% 不变 (跟 Sprint 3 baseline 一致)
- 解法: 扩 test case 到 50 (+20 data/legal 场景)
- 留 follow-up

## 6. 飞轮"运行" → "迭代" 阶段

决策者原话"专家数量够了" — 飞轮 L3 generation **停止扩**, 转质量 + 迭代:

- L3 generation API 配好 (DeepSeek 跑通, 10 真跑) — 飞轮可重启当需新 expert 时
- Quality audit 工具就位 (`scripts/expert-quality-audit.py`) — 后续可重跑
- 5 维度 4 PASS, 1 WARN, 1 FAIL — 总评 WARN, 留 3 债

## 7. 后续建议 (决策者拍)

| 优先级 | 行动 | 估时 |
|---|---|---|
| P0 | 合并 worktree 副本 (32 extended expert) | 1h, 派 Performer |
| P0 | Re-generate 10 expert with domain constraint | 1h, 派 Performer |
| P1 | 补 frontend + pm 触发词 | 30min, 派 Performer |
| P2 | 扩 M1 test case 30 → 50 | 1h, 派 Performer |
| P2 | Phase 3 review (累积 6+ EPIC 完整完成) | 1-2h, Master |

## 8. 关键洞察 (留教训)

- **数量估算 ≠ 实际 INDEX count**: 飞轮"运行"阶段"101 indexed"是估算, 实际 65. Quality audit 才是真相
- **L3 generation 域约束缺失**: 缺 prompt 约束, generated 跟 default 域冲突
- **Performer 任务 5/7 漏 2/7**: EPIC-028-B 扩 5/7 default expert trigger, frontend + pm 漏 — Performer 任务 narrow 还要再细
- **Audit 工具至关重要**: 没 quality audit, 3 真问题不揭露

---

**Author**: master
**Last updated**: 2026-06-09
**Status**: ⏸ WARN — 3 已知债, 待决策者拍修复时机
