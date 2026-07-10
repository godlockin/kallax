# KALLAX 工作流规则 — EPIC 三件套 + PHASE 完整完成 review

**Created**: 2026-06-07
**Status**: ✅ ACTIVE — 配合 EPIC-021 同步实施
**Author**: master_main
**Purpose**: 沉淀 EPIC 交付经验教训, 防止知识黑洞; PHASE 升级防止经验只沉淀不演进.

**用户决策 (2026-06-07)**: 接受"EPIC 三件套 + PHASE 完整完成 review"作为 KALLAX 硬规则, 写入 CLAUDE.md Rule 6 + 7.

---

## 0. 报告导读

| # | 章节 | 内容 |
|---|---|---|
| 1 | EPIC 交付三件套 | A+B review + 文档更新 + 经验教训 |
| 2 | PHASE 完整完成 review | 触发 + 流程 + 产出 |
| 3 | 模板清单 | 3 个新模板 (EPIC-LESSONS, PHASE-REVIEW, AB-REVIEW) |
| 4 | 触发节奏 | Phase 002 现状 + 何时触发下次 review |
| 5 | 责任分工 | 谁负责每步 |
| 6 | 跟既有规则的关系 | Rule 1-5 不变, Rule 6-7 是新增 |
| 7 | 决策点 | 等决策者拍板 |

---

## 1. EPIC 交付三件套 (CLAUDE.md Rule 6)

### 1.1 流程总览

```
EPIC 实施完成 (所有 ticket 实施 commit push)
    │
    ├──> 步骤 1: A+B 2-Group 对抗 review (master 派 2 sub-agent)
    │       ├──> A-Forward: AC + 代码质量 + 集成
    │       ├──> B-Attack: 安全 + 边界 + 攻击面
    │       └──> 修复 + master 仲裁 APPROVE/REJECT
    │
    ├──> 步骤 2: 文档更新 (master 主导)
    │       ├──> jira/tickets/EPIC-XXX/README.md 实施记录
    │       ├──> jira/epics/EPIC-XXX/epic.json ticket 状态
    │       └──> (可选) confluence/decisions/ 新决策文档
    │
    └──> 步骤 3: 经验教训总结 (master 主导, 模板化)
            ├──> jira/epics/EPIC-XXX/LESSONS-LEARNED.md
            ├──> 6 节必填 (量化/事件/教训/AB review/评估/下一步)
            └──> 配合 EPIC 实施 commit 同一 PR 提交
```

### 1.2 关键约束

- **不可跳过任何一步**. 缺 A+B review = ticket 不 close; 缺 LESSONS-LEARNED = EPIC 不算 done
- **A+B review 用 confluence/templates/AB-REVIEW-TEMPLATE.md** (新模板)
- **LESSONS-LEARNED 用 confluence/templates/EPIC-LESSONS-LEARNED-TEMPLATE.md** (新模板)
- **master 仲裁**: 决定 APPROVE/REJECT, 不能甩给 sub-agent

### 1.3 跟 EKET 对比

| 维度 | EKET | KALLAX |
|---|---|---|
| 经验沉淀 | commit message (易被淹没) | 独立 LESSONS-LEARNED.md (永久) |
| review 模板 | 无统一 | AB-REVIEW-TEMPLATE.md (强制) |
| 跨 EPIC 模式 | 无 | PHASE review 找 pattern |
| 升级到规则 | 无 | 升级到 CLAUDE.md (Rule 6+7) |

---

## 2. PHASE 完整完成 review (CLAUDE.md Rule 7)

### 2.1 触发条件

- **主触发**: 完成 3-5 个 EPIC (master 决定)
- **次触发**: 阶段目标达成 (e.g. "v1.0 准备好发布")
- **强制触发**: 决策者指令 ("做 phase review")

### 2.2 4-Group 流程 (跟 EKET Phase 1+2+3 借鉴, KALLAX 加 4)

```
Phase 1 (Architect 全局扫):
   - 读所有 EPIC LESSONS-LEARNED.md
   - 分类: 量化/流程/技术/治理/人员/工具
   - 输出: 跨 EPIC 模式 + 异常点

Phase 2 (5 专家并行, 600 tokens 视角):
   - 🏗️ Architect: 架构累积 / 漂移 / 债务
   - 💻 Backend: 性能 / 稳定性 / 兼容性
   - 🎨 Frontend: DX / 摩擦 / 触点
   - 🖌️ UX: 用户体验 / 决策树 / 引导
   - 📋 Product: 价值 / 路线图 / 北极星

Phase 3 (Master 仲裁 + 升级):
   - 查漏补缺: 哪些经验教训没覆盖
   - 纠错: 哪些跟事实不符
   - 归纳合并: 跨 EPIC 相似教训合并
   - 升级: 沉淀到 CLAUDE.md / architecture/

Phase 4 (决策者审批):
   - 升级项需决策者决策
   - master 不能自升级红线规则
```

### 2.3 产出物

- `confluence/decisions/PHASE-XXX-REVIEW-YYYYMMDD.md` (用 PHASE-REVIEW-TEMPLATE.md 模板)
- `CLAUDE.md` 修订 (如适用, 需决策者批准)
- `confluence/architecture/` 新文档 (如适用)

### 2.4 跟 EKET 对比

| 维度 | EKET | KALLAX |
|---|---|---|
| 跨阶段 review | 无 | 必走 (Rule 7) |
| 4-Group (加决策者审批) | 3-Group | 4-Group (Phase 4 是 gate) |
| 升级机制 | 无明确路径 | "升级项" 清单 + 决策者审批 |
| 经验量化 | 无 | 跨 Phase 对比表 (改善/退步) |

---

## 3. 模板清单 (新建)

| 路径 | 用途 | 何时用 |
|---|---|---|
| `confluence/templates/EPIC-LESSONS-LEARNED-TEMPLATE.md` | EPIC 经验教训文档 | 每个 EPIC 交付时 |
| `confluence/templates/PHASE-REVIEW-TEMPLATE.md` | PHASE 完整完成 review 文档 | 每 3-5 个 EPIC 后 |
| `confluence/templates/AB-REVIEW-TEMPLATE.md` | A+B review 记录 | 每个 ticket close 时 |

**3 模板配套实施**: 跟 CLAUDE.md Rule 6+7 同步发布.

---

## 4. 触发节奏 (Phase 002 现状)

### 4.1 当前 Phase 状态

| EPIC | 状态 | 经验教训 | 触发 |
|---|---|---|---|
| EPIC-016 (Init Performance) | ✅ done | ✅ EPIC-016-POSTMORTEM-2026-06-07.md | 已沉淀 |
| EPIC-021 (KALLAX 超越 EKET) | ✅ done | ⏳ 待写 (本规则生效后第一份) | 现在写 |

### 4.2 下次 PHASE review 触发

**Phase 002 候选 EPIC** (从 EKET 战略报告和待办):
- EPIC-022: Permission Model (决策者已决策, scope 缩到 v1)
- EPIC-018: O 安全 review 5 issue 修复
- EPIC-023/024/025: 3 治理预留 (DevOps/Data/Test) 启用

**触发时机**:
- 默认: 完成 EPIC-022 后 (3rd EPIC of Phase 002) → Phase 002 review
- 提前: 决策者指令
- 推迟: 4-5 个 EPIC 后 (但不超过 5)

### 4.3 EPIC-021 经验教训 (回填)

按 Rule 6 强制, EPIC-021 已完成但没写 LESSONS-LEARNED.md. **现在补**:
- 模板: `confluence/templates/EPIC-LESSONS-LEARNED-TEMPLATE.md`
- 路径: `jira/epics/EPIC-021/LESSONS-LEARNED.md`
- 内容: 6 节, 整合 5 专家 panel + 12 共识超越点 + 38 项 issue 修复

---

## 5. 责任分工

| 步骤 | 主责 | 协助 | 不能甩给 |
|---|---|---|---|
| A+B review 派发 | master | sub-agent (执行) | Performer (评审自己) |
| A+B review 修复 | Performer | sub-agent (指导) | master (代替 Performer 写代码) |
| 文档更新 | master | Performer (填内容) | sub-agent (无 context) |
| LESSONS-LEARNED | master | 5 专家 panel (review) | Performer (没全局视野) |
| PHASE review 派发 | master | 5 专家 panel | sub-agent (单点视角) |
| 升级 CLAUDE.md | master | 决策者审批 | sub-agent (无审批权) |

**红线**:
- ❌ master 自己写代码 (CLAUDE.md Conductor 禁止 #1)
- ❌ Performer 自我审查 (EPIC-016 Performer 禁止 #1)
- ❌ master 自升级红线规则 (需决策者审批)

---

## 6. 跟既有规则的关系

| Rule | 内容 | 跟新规则关系 |
|---|---|---|
| 1. 并行隔离 | worktree 隔离, file_scope 检查 | 不变 |
| 2. 错误处理 | 生产代码禁 expect/panic | 不变 |
| 3. 产出验证 | master 验证 Performer 真实性 | 不变 (Rule 6 强化) |
| 4. 资源管理 | 缓存 TTL | 不变 |
| 5. 类型安全 | 禁 any / @ts-ignore | 不变 |
| **6. 经验沉淀** | **EPIC 三件套** | **新增 (本规则)** |
| **7. PHASE 完整完成** | **跨 EPIC 升级** | **新增 (本规则)** |

**Rule 6+7 强化**:
- Rule 3 (产出验证): 之前 master 验证代码真实性, 现在加上 review + 经验沉淀
- Rule 5 (类型安全): 现在经验教训也是"类型", 不可 any-shape

---

## 7. 决策点 (决策者审批)

| # | 决策 | 默认建议 |
|---|---|---|
| 1 | 接受 Rule 6 (EPIC 三件套) 为硬规则? | ✅ 接受 (用户已确认) |
| 2 | 接受 Rule 7 (PHASE 完整完成 review) 为硬规则? | ✅ 接受 (用户已确认) |
| 3 | Phase 002 何时触发 review? | EPIC-022 后 (3rd EPIC) |
| 4 | EPIC-021 现在回填 LESSONS-LEARNED? | ✅ 立刻 (master 主导) |
| 5 | 3 模板 (EPIC/PHASE/AB) 配套发布? | ✅ 同步 (本 PR 包含) |
| 6 | Rule 6+7 写入 CLAUDE.md 还是另设? | CLAUDE.md 核心原则 (跟 Rule 1-5 同区) |

**默认 plan**: 全部接受, 立刻实施. 等待决策者最终拍板.

---

## 8. 关联文档

**新建** (本规则配套):
- `confluence/templates/EPIC-LESSONS-LEARNED-TEMPLATE.md` (新)
- `confluence/templates/PHASE-REVIEW-TEMPLATE.md` (新)
- `confluence/templates/AB-REVIEW-TEMPLATE.md` (新)
- `jira/epics/EPIC-021/LESSONS-LEARNED.md` (回填, 待 master 写)

**修订**:
- `CLAUDE.md` 加 Rule 6 + 7 (本 PR)

**待写** (Phase 002 review 时):
- `confluence/decisions/PHASE-002-REVIEW-2026MMDD.md`
- (可能) `confluence/architecture/` 新文档

**上游引用**:
- `confluence/decisions/EPIC-016-POSTMORTEM-2026-06-07.md` (Rule 6 触发根源)
- `confluence/decisions/EKET-SURPASS-STRATEGY-2026-06-07.md` (12 共识超越点)
- `confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md` (PHASE review 模板雏形)

---

**Reviewer(s)**: master_main (基于 EPIC-016 + EPIC-021 经验沉淀)
**Last updated**: 2026-06-07
**Status**: ✅ ACTIVE — 3 模板 + 2 规则同步发布, 等待决策者最终拍板
