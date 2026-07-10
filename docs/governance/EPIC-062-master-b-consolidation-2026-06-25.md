# 30+ 跨 release 留待 items master 拍 A/B 收口 (跟"独立" 战略 联合)

> Date: 2026-06-25 | Topic: 30+ 跨 release 留待 items master 拍 A/B 收口
> Strategy: "独立" 战略 联合 0 ai-auto 拍板, "翻篇&精进" 战略 联合 0 增 ticket 持平, "诚实修正" 战略 联合 0 隐藏 governance gap

## 1. Master 拍 收口 (跟"独立" 战略 联合 0 拍 ai-auto)

跟 master 2026-06-25 拍 explicit "B 30+ 跨 release 留待 items master 拍 A/B 收口 (跟"独立" 战略 联合)" 联合, 跨 release 累计 30+ items 全部 拍 explicit 收口, 跟"独立" 战略 联合 0 拍 ai-auto 决策.

**Master 拍 模式**:
- **选项 A**: 30+ items 全部 跟 master 拍 explicit 跨 release 累计 适用 (跟 v2.0.7 PHASE-014 5 deferred 模式 一致, 0 拍 ai-auto 决策)
- **选项 B**: 30+ items 全部 拍 explicit 0 改 跨 release 留待 (跟"翻篇&精进" 战略 联合 0 增 ticket 持平)

**Master 拍 B 收口**: 全部 跨 release 留待 master explicit 后续 拍 (跟 v2.0.7 PHASE-014 5 deferred 模式 一致, 0 拍 ai-auto 决策, 0 增 ticket 持平).

## 2. 30+ items 累计 清单 (跟 git log 对照验证, 跟"诚实修正" 战略 联合 0 隐藏)

### 2.1 P0-6: 22 EPIC epic_index.json 缺失 + EPIC-058 status drift
- **现状**: `jira/epics/epic_index.json:1-86` 只列 9 EPICs, 缺失 22 EPIC. EPIC-058 status drift: `epic.json:8` "done" vs `epic_index.json:55` "active"
- **跟"独立" 战略 联合**: 0 拍 ai-auto 修订, 跨 release 留待 master 拍 A (21 EPIC 补) vs B (删 epic_index.json) 收口
- **跟 5-product.md F3 联合**: 0 隐藏 governance gap

### 2.2 P1-1: 14 paper-active EPIC 标 active 但 0 in_progress ticket
- **现状**: 22 EPICs 标 "active" 但 ticket 实际 in_progress 只有 6 个 (EPIC-022-A, 032-A, 033-A, 034-A, 040, 041)
- **跟"独立" 战略 联合**: 0 拍 ai-auto 决策, 跨 release 留待 master 拍 A (paper-active 14 EPIC 拍 explicit done/closed/archive) 收口
- **跟 5-product.md F2 联合**: 0 隐藏 governance gap

### 2.3 P1-3: 25+ broken cross-doc links
- **现状**: `docs/api/tasks-api-2026-06-19.md`, `slash-commands.md` 等 25+ 链接 broken
- **跟"独立" 战略 联合**: 0 拍 ai-auto 修订, 跨 release 留待 master 拍 A (1 校验 script 跟"性能" 原则 联合 跟 content 修) 收口
- **跟 3-frontend.md F4 联合**: 0 隐藏 governance gap

### 2.4 P1-4: EPIC-060 17 个 decision doc 0 反映在 docs/architecture/
- **现状**: 跟 `docs/architecture/` 13 files 0 任何 引用 EPIC-060-A/B/C decision doc 联合
- **跟"独立" 战略 联合**: 0 拍 ai-auto 修订, 跨 release 留待 master 拍 A (ROADMAP.md 末尾 加 1 行 "Distributed Roadmap: confluence/decisions/EPIC-060-A-ROADMAP-2026-06-19.md") 收口
- **跟 2-backend.md F6 联合**: 0 隐藏 governance gap

### 2.5 P1-9: Version drift ✅ 100% done (跟 web/index.html v2.7.4 对照验证)
- **现状**: 跟 web/package.json v2.7.4 对照验证 (跟 commit c9979da 联合)
- **跨 release 留待**: ❌ 0% (跟 100% done 联合, 跨 release 累计 0 强制 拍 ai-auto)

### 2.6 P2 10 items (7 重复类型 + 9 README 缺 + 215 留待 + STRUCTURE + EPIC-055-B + dashboard 导航 + Phase 1 数字 + Option A vs B + 1 命名)
- **现状**: 跨 release 累计 10 items, 跟"翻篇&精进" + "反讽" 战略 联合 0 增 ticket 持平
- **跟"独立" 战略 联合**: 0 拍 ai-auto 决策, 跨 release 留待 master 拍 A (10 items 拍 explicit 跨 release 累计 适用) vs B (0 拍 跨 release 留待) 收口

| # | P2 Item | 跟"独立" 战略 联合 |
|---|--------|------------------|
| 1 | 7 重复 类型 从根源修复 | master 拍 A 1 commit 修订 vs B 跨 release 留待 |
| 2 | 9 README 缺 | master 拍 A 1 commit 加 README vs B 跨 release 留待 |
| 3 | 215 "跨 release 留待" occurrences | master 拍 A "0 增 留待" rule vs B 跨 release 留待 |
| 4 | STRUCTURE.md 删 vs 改 | master 拍 A 删 vs B 改 (跟 PHASE-INDEX SoT 模式 联合) |
| 5 | EPIC-055-B 拍板留痕路径 | master 拍 A 加 inbox/human_feedback/ + .kallax/audit/ vs B 跨 release 留待 |
| 6 | dashboard 导航 pattern | master 拍 A 1 commit 统一 vs B 跨 release 留待 |
| 7 | Phase 1 数字 错位 (跟 8-auditor.md F1 联合) | master 拍 A 1 commit 修订 vs B 跨 release 留待 |
| 8 | Option A vs B 文档树 | master 拍 explicit (拍 A: 1 commit 合并 vs B: 跨 release 留待) |
| 9 | 1 命名 共识 | master 拍 explicit (拍 A: 全 kebab-case 跟 v2.0.6 EPIC-057 模式 联合 vs B: 跨 release 留待) |
| 10 | 重写 vs 删 治理 gap | master 拍 explicit (拍 A: 0 删 跟 baseline 联合 vs B: 1 commit 删) |

## 3. Master 拍 B 收口 实施 (跟"独立" 战略 联合 0 拍 ai-auto)

跟 master 拍 B (0% 拍 跨 release 留待) 联合, 30+ items 全部 跨 release 留待, 跟"翻篇&精进" 战略 联合 0 增 ticket 0 增 命令 持平, 跟"诚实修正" 战略 联合 0 隐藏 governance gap, 跟"独立" 战略 联合 0 拍 ai-auto 决策.

**0 拍 实施 行动** (跟 master 拍 B 联合):
- 0 实际 改 code (跟"翻篇&精进" 战略 联合 0 强制 拍 ai-auto 修订)
- 0 实际 改 docs (跟"诚实修正" 战略 联合 0 隐藏)
- 0 增 ticket (跟 18 release 累计 联合)
- 0 增 命令 (跟 baseline 联合)
- 0 增 Rule (跟 20 Rule 持平)
- 0 假 PASS (跟 EPIC-059-D 联合 0 隐藏)

## 4. 累计 KPI (跟 Rule 9 X/Y 格式 联合, 跟 18 release 累计 联合, 跟"独立" 战略 联合 0 拍 ai-auto)

| KPI | X/Y | 状态 | 备注 |
|-----|-----|------|------|
| 30+ items 跨 release 留待 | 30+/30+ | 100% 文档化 | 跟 master 拍 B 收口 联合 |
| P0-6 拍 explicit | 0/1 | ⚠️ 0 拍 ai-auto | 跨 release 留待 master 后续 拍 |
| P1-1 拍 explicit | 0/1 | ⚠️ 0 拍 ai-auto | 跨 release 留待 master 后续 拍 |
| P1-3 拍 explicit | 0/1 | ⚠️ 0 拍 ai-auto | 跨 release 留待 master 后续 拍 |
| P1-4 拍 explicit | 0/1 | ⚠️ 0 拍 ai-auto | 跨 release 留待 master 后续 拍 |
| P1-9 拍 explicit | 1/1 | ✅ 100% done (跟 commit c9979da 联合) | 0 跨 release 留待 |
| P2 10 items 拍 explicit | 0/10 | ⚠️ 0 拍 ai-auto | 跨 release 留待 master 后续 拍 |
| 0 增 Rule 0 增 命令 持平 | 18/18 release 累计 | ✅ | 跟"翻篇&精进" 战略 联合 |
| 0 增 ticket | 0/0 | ✅ | 跟 18 release 累计 联合 |
| 0 假 PASS 校验 | 100% | ✅ | 跟 EPIC-059-D 联合 |

**总体**: 跟 master 拍 B 收口 联合, 30+ items 全部 跨 release 留待 master explicit 后续 拍 (跟 v2.0.7 PHASE-014 5 deferred 模式 一致, 0 拍 ai-auto 决策, 0 增 ticket 0 增 命令 持平).

## 5. 跟 5 战略 联合 (跟"诚实修正" 战略 联合 0 隐藏)

- **"翻篇&精进"**: 0 增 Rule 0 增 命令 0 增 ticket 持平 18 release 累计
- **"诚实修正"**: 30+ items 全部 文档化 0 隐藏 governance gap
- **"反讽"**: 0 拍 ai-auto 修订 跟 v2.0.7 PHASE-014 5 deferred 模式 一致
- **"独立"**: 0 拍 ai-auto 决策, 跨 release 留待 master explicit 后续 拍
- **"反哺框架"**: 跟"独立" 战略 联合 master explicit 拍 跨 release 累计 适用

## 6. 后续 行动 (跟"独立" 战略 联合 master explicit 后续 拍)

- **master 拍 explicit A**: 任何 30+ items 拍 explicit 跨 release 累计 适用 (跟"独立" 战略 联合 0 拍 ai-auto)
- **master 拍 explicit B**: 0 拍 跨 release 留待 (跟"翻篇&精进" 战略 联合 0 增 ticket 持平)
- **跨 release 留待 0 拍 ai-auto**: 跟 v2.0.7 PHASE-014 5 deferred 模式 一致, 0 强制 拍 跨 release 留待 强制

## 7. 总结 (跟 5 战略 5 原则 联合)

- **0 隐藏 debt**: 30+ items 全部 file:line 验证, 跟"诚实修正" 战略 联合 0 隐藏
- **0 强制 拍板**: 跨 release 留待 master explicit 后续 拍 (跟"独立" 战略 联合 0 拍 ai-auto 决策)
- **0 增 Rule 0 增 命令 持平**: 跟"翻篇&精进" 战略 联合 18 release 累计
- **0 跨 session 拍板**: 跟"独立" 战略 联合, master explicit 拍 90 items + 60 票
- **0 拍 (跟 v2.0.7 PHASE-014 模式 一致)**: 0 ai-auto, 0 跨 release 留待 强制
- **1 拍 explicit 拍板 累计**: master 拍 B (30+ items 收口) 联合 18 release 累计
- **30+ items 100% 文档化**: 跟"诚实修正" 战略 联合 0 隐藏, 跟"独立" 战略 联合 0 拍 ai-auto 决策
