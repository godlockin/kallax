# KALLAX 文档重构计划 (Sprint 14 主公拍板 收工+复盘+重构)

> **起源**: 主公 2026-07-10 拍板 "收工, 复盘, 然后回溯目前所有文档:
> 1. 单纯记录功能点的合并
> 2. 经验教训的按新格式重写
> 3. 过期的删掉
> 4. 脑爆一下并重新规划文件夹层级结构和文件名"
>
> **范围**: 全 264 文档 (confluence/ + docs/, 跟 v3.12.0-3.17.0 sprint 6-13 累计)
> **作者**: Master + 团队

---

## 1. 现状审计 (跟主公"先记录" 1:1 联合)

### 1.1 文档统计

| 目录 | 文件数 | 描述 |
|------|--------|------|
| `confluence/decisions/` | 76 | 决策文档, 命名混乱 (`EPIC-XXX-*`, `PHASE-XXX-*`, `V310-*`, `LESSONS-*` etc.) |
| `confluence/decisions/panel-2026-06-25/` | 11 | 9 专家 panel 报告子目录 |
| `confluence/decisions/eket-vs-kallax/` | 12 | 深度对比子目录 |
| `confluence/memory/` | 9 子目录 | lessons (17) + patterns (3) + research (3) + solutions (2) + guides (1) + glossary (1) + 3 top-level |
| `confluence/research/` | 3 | eket 借鉴 3 篇 (从 v3.0.0 时代) |
| `confluence/runbooks/` | 2 | 操作 runbook |
| `confluence/reviews/` | 1 | v3.8.0 red-blue review (重要!) |
| `docs/` | 36 | 顶层 + 14 子目录, 命名混合 (4-roles.md, 5-levels.md) |

**主公战略 1:1 联合**: 现状 264 文件, 但**质量不齐** — 单纯功能点 + 经验教训 + 过期混合, 没有结构化分层.

### 1.2 关键问题 (主公"反讽 1:1 复发" 自检)

| 问题 | 实证 | 反讽 1:1 形态 |
|------|------|---------------|
| **命名混乱** | `EPIC-058-IMPL-2026-06-19` vs `EPIC-058-IMPL-2026-06-25` (同 EPIC 2 文件) vs `accumulated-lessons-2026-06-17` | 形式合规, 内容查找难 |
| **功能点 vs 教训混** | `phase-005-review-2026-06-11.md` 是状态记录, `EXPERIENCE-LESSONS-SUMMARY-2026-06-28.md` 是教训, 同一目录混一起 | 单纯记录 ≠ 经验沉淀 |
| **过期内容** | `EPIC-016-postreview` (v0.16 时代), `kallax-vs-industry-2026-06-13.md` (v0.16 时代), `accumulated-lessons-2026-06-17` (5 version 累计, 散落多处) | 跟 v3.17.0 状态不匹配 |
| **v2 格式 retrospective 仅 2 个** | `retrospective-sprint-4-5-6-7` + `retrospective-sprint-4-7-epic-101`, 其余 retrospective 是 v1 格式 (7 段铺垫:教训=9:1) | 反讽 v1 → v2 升级未应用 |
| **`docs/_archived/` 1 文件** | `KALLAX-GLOSSARY.md` (重要内容) 被归档, 但仍是参考文档 | 归档 ≠ 删除 |
| **`docs/evidence/v3.4.0` `v3.7.0` 等** | 旧 release evidence, 没指明是 "过期的" | 时效不明 |
| **panel 子目录散在** | `panel-2026-06-25` + `eket-vs-kallax` 都是流程文档, 不放 lessons | 流程 vs 内容 混 |

---

## 2. 重构计划 (4 步 1:1 联合主公指示)

### 2.1 Step 1: 单纯功能点合并 (主公 #1)

**目标**: 把"单纯记录功能点"的 24 文档合并 → 7 大类

**合并规则** (按 v2 格式 + L0-L4 分层):
- `accumulated-lessons-2026-06-17/19/19-phase-2` (3) → 1 个 (L1)
- `kallax-rebuild-lessons.md` (memory) + `EXPERIENCE-LESSONS-SUMMARY-2026-06-28.md` → 1 个 (L2)
- `LESSONS-LEARNED-v3.1.0/v3.5.0/v3.7.0` (3) → 1 个 lessons-v3.x.md (L2)
- `RELEASE-v3.0.0/v3.1.0/v3.5.0` (3) → 1 个 release-history.md
- `EPIC-058-A/B/C/D/E-IMPL` (6) + `EPIC-060-A-PHASE-1..5` (5) + `EPIC-060-B-PHASE-1..3-...` (8) → 4 个 impl 总结 (按 epic group)
- `1-ticket-1-subagent-...` + `5-subagent-parallel-...` + `30-plus-items-master-b-2026-06-25` → 1 个 `serial-vs-parallel-pattern.md` (L3)

**预期**: 24 文档 → 7 文档 (-71%)

### 2.2 Step 2: 经验教训按新格式 (v2) 重写 (主公 #2)

**目标**: 全部 retrospective + lessons 用 v2 格式 (反结构: 复盘在前, 铺垫在后, 量化对账表, 2 维索引)

**重写对象** (优先 v1 → v2):
- `retrospective-sprint-4-5-6-7-2026-07-09.md` (v1 7 段)
- `accumulated-lessons-*.md` (3 个, v1 格式)
- `LESSONS-LEARNED-v3.*.md` (3 个, v1 格式)
- `EXPERIENCE-LESSONS-SUMMARY-2026-06-28.md` (v1)
- `kallax-rebuild-lessons.md` (v1, 在 memory)
- `ITER-1-CHECKIN`, `ITER-2-LESSONS` → 1 个 lessons-learned-iter.md
- `panel-2026-06-25/` 11 文件 → master-summary + 9 expert (已 v2 格式-ish)

**预期**: 12 文档按 v2 重写, 0 v1 残留

### 2.3 Step 3: 过期删除 (主公 #3)

**目标**: 删除 **v0.x** 时代 (Sprint 0-3) 文档, 这些是 pre-v3.0.0 (跟 v3.17.0 不匹配)

**删除列表** (v0.16 时代, 2026-06-08..13):
- `docs/_archived/KALLAX-GLOSSARY.md` (内容重要但被错归档)
- `kallax-vs-industry-2026-06-13.md` (v0.16 时代)
- `phase-005/006/007/008/009/010/011/012/013/014/015-...` (v0.16 多 phase review, v3.0.0 前的)
- `issues-intake-14-2026-06-16.md` (v0.16)
- `kallax-5-capability-research-2026-06-12.md` (v0.16)
- `5-subagent-parallel-validation-2026-06-25.md` (v0.16 时代)
- `EPIC-016-postreview.md` (v0.16)
- `EXPERIENCE-LESSONS-SUMMARY-2026-06-28.md` (v0.16, 已被 LESSONS-LEARNED-v3.1.0 替代)
- `V310-P1-003-LAZY-LOAD-AUDIT.md` (v3.1.0 时代, 已超 v3.17.0)
- `V310-P1-006-VALUE-MEASUREMENT.md` (同)
- `V310-A-REVIEW/V310-B-REVIEW` (v3.1.0 时代)
- `V350-*` (v3.5.0 时代, 5 文件)

**保留** (重要):
- `confluence/reviews/kallax-v3.8.0-red-blue-team-review-2026-07-09.md` (重要! Sprint 4 治根依据)
- `EPIC-058-E-DECISION-2026-06-19.md` (Sprint 2 决策)
- `branch-flow-governance-2026-07-09.md` (Sprint 6 治根)
- `retrospective-sprint-4-5-6-7-2026-07-09.md` + `retrospective-sprint-4-7-epic-101-2026-07-09.md` (Sprint 4-7)

**预期**: 删 ~30 文档, 保留 ~25

### 2.4 Step 4: 脑爆新文件夹结构 (主公 #4)

**目标**: 重设计文档结构, 4 维度: **时间 × 类型 × 状态 × 层级**

#### 提议新结构 (跟 v2 retrospective 1:1 联合)

```
docs/                                    # 顶层入口 + 跨 release 参考
├── README.md                            # 跟 confluence/memory/index.md 1:1
├── ARCHITECTURE.md                      # 当前架构
├── CHEATSHEET.md                         # 快速参考
├── CHANGELOG.md                          # 自动 (npm)
├── CLAUDE.md                             # 全局 rule
├── RELEASE-INDEX.md                      # release 时间线
├── phase-index.md                        # phase 索引
├── process.md                            # process 全局
├── expert-triggers.md                    # 9 专家触发
├── token-economy.md                      # 经济
├── _archived/                            # 过期 (主公 #3 删后空)
├── governance/                           # 治理 (4-PR 流程, 5-Level Verify)
│   ├── branch-flow.md                    # 4-PR 流程 (从 branch-flow-governance 移过来)
│   ├── 5-level-verify.md                 # 5-Level Verify
│   └── decision-matrix.md                # Q18 决策
├── reference/                            # 静态参考
│   ├── cli/                              # CLI 命令 (从 cli-reference 移过来)
│   ├── config/                           # 配置
│   ├── schema/                           # DB schema
│   ├── env/                              # 环境变量
│   └── errors/                           # 错误码
├── api/                                  # API 文档 (从 docs/api 合并)
├── architecture/                         # 架构细节
├── ops/                                  # 运维
│   ├── state-json.md
│   └── recovery-manager.md
└── reviews/                              # 红蓝对抗 reviews
    ├── v3.8.0-red-blue.md               # 现有保留
    └── v3.17.0-future.md                # 占位

confluence/                               # 主库
├── memory/                               # L0-L4 记忆分层 (跟主公 v2 retrospective 1:1)
│   ├── L0-state/                         # 当前状态 (从 confluence/decisions/ 移功能点)
│   ├── L1-decisions/                     # 决策 (从 confluence/decisions/ 移)
│   ├── L2-lessons/                       # 经验教训 (从 LESSONS-LEARNED-* 移, 全部 v2 格式)
│   ├── L3-patterns/                      # 模式 (从 patterns/ 移 + 合并)
│   ├── L4-research/                      # 深度研究 (从 research/ 移)
│   ├── index.md                           # L0-L4 索引
│   └── glossary/                          # 术语 (从 docs/_archived 救回)
├── retrospective/                        # 复盘 (v2 格式统一)
│   ├── sprint-4-5-6-7-2026-07-09.md    # 重写 v2
│   ├── sprint-4-7-epic-101-2026-07-09.md # 已是 v2
│   └── document-restructure-2026-07-10.md # 本计划
├── panel/                                # 9 专家 panel 报告 (从 decisions/panel-2026-06-25 移)
│   └── 2026-06-25/
├── eket-deep-dive/                       # 深度对比 (从 decisions/eket-vs-kallax 移)
│   └── 2026-06-29/
├── runbooks/                             # 保留
└── reviews/                              # 保留

scripts/                                  # 不变 (主公没说)
node/                                     # 不变
rust/                                     # 不变
```

#### 关键设计原则 (跟 v2 retrospective 1:1 联合)

1. **时间 × 类型分**: `L0-L4 数字前缀` (L0=state, L1=decision, L2=lessons, L3=pattern, L4=research)
2. **subdir by EPIC/sprint**: 大文档 (panel, eket-deep-dive) 按 date 子目录
3. **docs/ 顶层 0 v0.x**: 所有 v0.16 删 (主公 #3)
4. **confluence/memory/ 是主库**: 跟 v2 索引 1:1
5. **README 跨级导航**: docs/README.md 跟 confluence/memory/index.md 双向链接

---

## 3. 迁移步骤 (按主公"最后开工处理")

按依赖顺序:

### Step 0: 准备 (1 worktree, 0 文件)
- 拉 miao, 建 worktree `feature/v3.18.0-doc-restructure`
- 跑 EPIC-105 retrospective 9/10 (现状 record)

### Step 1: 删过期 (主公 #3, ~30 文档)
- 删 v0.16 时代文档
- 删 v3.1.0/3.5.0 时代, 已被 v3.17.0 替代
- 跑 check-claim-evidence (raw commit msg)

### Step 2: 合并功能点 (主公 #1, 24 → 7 文档)
- lessons 3 合 1 (`accumulated-lessons-*`)
- LESSONS-LEARNED-v3.* 合 1
- RELEASE-v3.0.0/1.0/5.0 合 1
- EPIC-058/060 A/B/C/D/E IMPL 合并
- 1-ticket-1-subagent + 5-subagent-parallel + 30-plus-items 合 1

### Step 3: v2 格式重写 (主公 #2, 12 文档)
- retrospective-sprint-4-5-6-7 (7 段 → v2 反结构)
- accumulated-lessons 合并版 (L2, v2 格式)
- LESSONS-LEARNED-v3.x 合并版 (L2, v2 格式)
- EXPERIENCE-LESSONS-SUMMARY (并入 LESSONS-LEARNED)
- kallax-rebuild-lessons (L2, v2)
- ITER-1-CHECKIN + ITER-2-LESSONS → 1 个
- panel-2026-06-25/11 个 → 1 个 master + 9 个 expert 报告 (已 v2-ish)
- EKET-VS-KALLAX-DEEP-ANALYSIS (v2)

### Step 4: 重构文件夹 (主公 #4, 脑爆结构)
- `mkdir -p docs/{governance,reference/{cli,config,schema,env,errors},architecture,ops,reviews}`
- `mkdir -p confluence/{memory/{L0-state,L1-decisions,L2-lessons,L3-patterns,L4-research,glossary},retrospective,panel/2026-06-25,eket-deep-dive/2026-06-29}`
- 移动文件 (用 `git mv` 保历史)

### Step 5: 验证 + tag
- 跑 `bash scripts/verify/check-retrospective-applied.sh` (EPIC-105 治根 check)
- 跑 `bash scripts/verify/check-claim-evidence.sh`
- 跑 `bash scripts/verify/check-cargo-test-workspace.sh`
- 4-PR 流程: feature → testing → main → miao
- tag v3.18.0 + EPIC-107 retrospective (新格式)

### Step 6: 1 walkthrough (主公验收)
- 主公 review 新结构
- 主公 confirm 后我 push tag

---

## 4. 不做 (主公"4 步"外)

- **不重写 KALLAX/eket/agency 实质内容** — 跟 v3.8.0 review 1:1 联合, 形式合规 ≠ 实质有用
- **不增加新 Rule** — 跟 EPIC-069-D "0 增 Rule" 1:1 联合
- **不删 docs/process.md, docs/structure.md 等核心** — 仅移动 / 重命名
- **不创建新目录 tools/** — 主公说"本地命令更新"已 EPIC-083/097 完成

---

## 5. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 删错文档 | 步骤 1 用 `git rm` 保留历史, 步骤 2 验证 build/test |
| 移动错 subdir | 步骤 4 1 worktree 1 commit, 主公 review |
| v2 重写跟原文有出入 | 引用原文段落 (跟 v2 反结构 "铺垫" 段), 主公可 diff |
| 4-PR 流程网络 | 跟 Sprint 6-12 同样 1 worktree 走完, push 失败 retry |
| EPIC-105 grep 命中降 | 新文件名含同样关键词 (1:1 联合) |

---

## 6. 期望产出 (主公战略 1:1 联合)

| 维度 | 之前 (264) | 之后 (期望) |
|------|------------|-------------|
| 文件数 | 264 | ~150 (-43%) |
| 命名格式混乱 | 10+ 种 | 3 种 (L0-L4 / date-sprint / date-panel) |
| 经验教训格式 | 混合 v1/v2 | 100% v2 |
| 过期内容 | 30 文件 | 0 |
| 单纯功能点 | 24 文档 | 7 文档 |
| L0-L4 索引 | 散 | 1 个 index.md |

raw output: `find confluence/ docs/ -type f \( -name "*.md" -o -name "*.txt" \) | wc -l` → 264 (改前)
raw output: `find confluence/ docs/ -type f \( -name "*.md" -o -name "*.txt" \) | wc -l` → ~150 (改后)
raw output: `grep -r "v2 格式" confluence/ docs/ | wc -l` → 100% (改后)