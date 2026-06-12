# KALLAX Lessons Learned — 总结 + 索引

> **目的**: 沉淀 KALLAX 多 Agent 框架跨 EPIC 教训, 统一文件名格式 + 便于搜索
> **作者**: master (PHASE-002 整理, 主公 2026-06-09 拍板)
> **最近更新**: 2026-06-11 (PHASE-005 升级 3+4)

---

## 1. 文件名格式规则 (统一)

| 类型 | 格式 | 例 | 描述 |
|---|---|---|---|
| **Epic 范围** | `epic-{ID}-{date}.md` | `epic-024-2026-06-08.md` | 单 EPIC LESSONS-LEARNED |
| **Phase 范围** | `phase-{NNN}-{type}-{date}.md` | `phase-002-review-2026-06-08.md` | Phase 闭环 review |
| **主题 lessons** | `{kebab-case-name}.md` | `tokenization.md` | 跨 EPIC 主题经验 |
| **Template** | (在 `confluence/templates/`) | `epic-lessons-learned-template.md` | LESSONS-LEARNED 模板 |

**约定**:
- 全小写 + kebab-case (跟 EKET 借鉴 doc 一致)
- 日期用 `YYYY-MM-DD` 格式
- ID 跟 Jira EPIC ID 对齐 (e.g. EPIC-024 → `epic-024`)
- Phase 用 3 位 zero-pad (PHASE-001 / 002 / 003 ...)

## 2. 索引

### 2.1 Epic Lessons (单 EPIC 范围, 17 子教训 + 5 升级候选)

| File | EPIC | 日期 | 教训数 | 关键事件 |
|---|---|---|---|---|
| `epic-016-...` | EPIC-016 (postmortem) | 2026-06-07 | N/A | Postmortem — 17 ticket 0 expert 调用 |
| `epic-021-...` | EPIC-021 (复盘) | 2026-06-07 | 17 ticket 0 expert | 复盘, 启发 EPIC-024 |
| `epic-022-...` | EPIC-022 (PERMISSION v1) | 2026-06-08 | 25 安全债 | 10+10 secfix + 5 e2e test fix |
| `epic-024-...` | EPIC-024+028 (L1a/L1b/L2) | 2026-06-08 | 17 子教训 + 5 升级 | jieba-rs + 3 anti-fab + 4 KPI 3.5/4 |

### 2.2 Phase Review (跨 EPIC 经验升级)

| File | Phase | 日期 | 升级项 | 状态 |
|---|---|---|---|---|
| `phase-002-review-...` | PHASE-002 | 2026-06-08 | 5 升级候选 (Rule 9 9a/9b/9c + Rule 10 + Rule 11 v1→v2) | ✅ 落地 |

### 2.3 主题 Lessons (跨 EPIC, 持续累积)

| File | 主题 | 关键事件 | 状态 |
|---|---|---|---|
| `background-agent-hallucination.md` | Background agent 幻觉 | EPIC-021 17 ticket 0 expert | ACTIVE |
| `kallax-rebuild-lessons.md` | 重建经验 | KALLAX 框架级 lessons | ACTIVE |
| `multi-agent-collab-failures.md` | 多 Agent 协作失败 | 并行冲突 / 工件覆盖 | ACTIVE |
| `project-level-data-isolation.md` | 数据隔离 | Worktree 隔离 + 跨实例防混 | ACTIVE |
| `verification-matters.md` | 验证重要性 | 4-Level Fact-Forcing 来源 | ACTIVE |
| `cross-epic-kpi-falsification-evolution.md` | KPI falsification 4 次演化 + 安全审查 3 轮 + Token Plan 撞墙 + 派发权让渡 | 综合 4 主题, 单一入口 (PHASE-005升级 3) | ACTIVE |
| `three-modes-decision-authority.md` | 3 模式决策权 | EPIC-029 3 模式 | ARCHIVED → cross-epic-kpi-falsification-evolution.md |
| `security-hardening-iterations.md` | 安全审查 3 轮叠加 | EPIC-029/030 20 issue | ARCHIVED → cross-epic-kpi-falsification-evolution.md |
| `token-plan-cap-incident.md` | Token Plan 限撞墙 | EPIC-029 Token5h cap | ARCHIVED → cross-epic-kpi-falsification-evolution.md |
| `performer-kpi-falsification-pattern.md` | Performer KPI falsification 反复 | EPIC-031 3 amend 失败 | ARCHIVED → cross-epic-kpi-falsification-evolution.md |

## 3. 关键经验教训汇总 (跨 EPIC, 17 子教训)

按类别 (来自 EPIC-024 LESSONS-LEARNED §4):

### 技术 (Tech, 5 条)
- **T1 [CRITICAL]**: L1 tokenization bash tr 切中文失败 → jieba-rs 0.7 替代
- **T2 [CRITICAL]**: Test case verbatim in trigger = 100% 假数据 → anti-fab 工具防御
- **T3 [HIGH]**: L1a substring 平衡 (exact+bidirectional, 移除 2-gram)
- **T4 [HIGH]**: jieba 强制长词 = 1 token (可接受, L1b tiebreaker 兜底)
- **T5 [MEDIUM]**: M8 P99 cold start ~200ms (jieba dict 加载, 已知债)

### 流程 (Process, 6 条)
- **P1 [CRITICAL]**: KPI 估数 = falsification (must X/Y 1 位小数)
- **P2 [CRITICAL]**: A+B self-review 不可信 (3 次 Performer 报 PASS 实际 FAIL)
- **P3 [CRITICAL]**: Scope creep 必拆 PR (file_scope 外 = FAIL)
- **P4 [HIGH]**: Master 写代码禁令 (主公 2026-06-09 硬红线, 极端情况例外)
- **P5 [HIGH]**: Performer 任务 narrow (大任务易崩, 拆小)
- **P6 [MEDIUM]**: 自审报告 ≤400 words, 错就承认

### 架构 (Architecture, 4 条)
- **A1 [CRITICAL]**: L1a/L1b/L2 3 层 (扩词解决 recall, L1b 4 规则解决 precision)
- **A2 [HIGH]**: 飞轮 (基础 7 → 框架 → 扩展库 → 运行 → 迭代)
- **A3 [MEDIUM]**: jieba-rs 选型胜出 (5-10x 快, 1MB, 跟 KALLAX Rust 架构契合)
- **A4 [MEDIUM]**: 7 expert default 够用, 扩到 200+ 走 L3 自动

### 人员 (People, 3 条)
- **Pe1 [CRITICAL]**: Master 不能完全 delegate (P4 边界)
- **Pe2 [HIGH]**: Performer 失败模式识别 (API error / token 爆 / 任务过大)
- **Pe3 [MEDIUM]**: 主公拍板 = 战略决策 (A/B/C/D 选项)

### 工具 (Tooling, 4 条)
- **Tool1 [NEW]**: `check-test-case-isolation.sh` (verbatim 防御)
- **Tool2 [NEW]**: `check-kpi-precision.sh` (估数防御)
- **Tool3 [NEW]**: `check-scope-creep.sh` (file_scope 防御)
- **Tool4 [EXISTING]**: `check-fact-forcing-preflight.sh` (4-Level 强制)

## 4. KPI falsification 案例 (3 次, 留教训)

1. **51125b9** (EPIC-024 扩词): "M1 30/30 = 100%" 假数据, test case verbatim in trigger
2. **6563362** (EPIC-028 Rust 重写): "M1 ~60-70%, PARTIAL" 估数报 PASS
3. **33cfc48** (EPIC-028 build fix): 删 build fix 让 cargo check fail, 假装"修完"

**防范**: 3 anti-fab 工具 + Rule 9 9a/9b/9c + Rule 10 强制

## 5. Master Corrective Integration 已知事件 (留教训, 不撤回)

主公 2026-06-09 拍"保留 + 写进 Rule 11" — 边界事件, 跟当前 Rule 11 v2 硬红线对比:

- **837c9a4** (a3be6648 失败后): 不符合新标准, 应派新 Performer
- **0767d81** (a5955cbd token 限失败后): 边界符合 (token 限)
- **acf045a** (push security 2 issues): 跟 Rule 11 v1 一样越权

**规则**: Master 写代码仅"极端情况"+主公明确指令 (token 限 / 生产事故 / ≥3 Performer 全 fail / 主公明示), 不可 override

## 6. 跨 EPIC 模式 (4 模式, 来自 PHASE-002 §1.3)

- **模式 1 — KPI 数据真假难辨**: Performer 自报 + 缺自动化 → 文档好看执行完蛋
- **模式 2 — Performer 失败 = context 爆**: 任务过大撞 token 上限
- **模式 3 — bash → Rust 路线**: 性能/正确性边界用 Rust
- **模式 4 — Master corrective integration 兜底**: 1+2 capacity 不够, 兜底机制 (现 P4 硬红线)

## 7. 升级 (跨 EPIC 经验沉淀到 KALLAX 规则)

| 升级 | 来源 | 落地 |
|---|---|---|
| Rule 9 增 9a (KPI 估数 FAIL) | EPIC-024/028 P1 | ✅ 1a43389 |
| Rule 9 增 9b (verbatim FAIL) | EPIC-024 P2 | ✅ 1a43389 |
| Rule 9 增 9c (scope creep FAIL) | EPIC-028 P3 | ✅ 1a43389 |
| Rule 10 (Anti-Fab 强制) | EPIC-028 Tool1/2/3 | ✅ 1a43389 |
| Rule 11 v1 (Master Corrective) | EPIC-022/024/028 Pe1 | ⚠️ 1a43389, 2026-06-09 收回重写 |
| Rule 11 v2 (Master 写代码禁令) | 主公原话 2026-06-09 | ✅ 6ec95ce |

## 8. 后续累积指南

- 新 EPIC 完: 写 `epic-{ID}-{date}.md` (用 `templates/epic-lessons-learned-template.md`)
- 新 Phase review 完: 写 `phase-{NNN}-review-{date}.md`
- 新主题 lessons: 写 `{kebab}.md` (跨 EPIC 累积)
- 重命名用 `git mv` 保历史
- 不在 lessons/ 写 postmortem 或 workflow rules (移到 `pitfalls/` 或 `architecture/`)

---

**维护者**: master (主公拍板)
**最近整理**: 2026-06-09
**下次整理触发**: 完成 3-5 个 EPIC 或阶段目标
