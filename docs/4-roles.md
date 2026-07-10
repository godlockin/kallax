# KALLAX 4 Roles

> KALLAX 4 角色模型: Conductor + Performer (含 4 sub-roles), 跟 eket Master-Slaver 概念 有交集但保留 3 层区分

## 总览

```
master (1)
   ├── Conductor (分析/拆解/审核/合并/发布)
   └── Performer (1+4 容量)
       ├── coder    (写代码 + commit)
       ├── reviewer (审 PR + A/B review + 跨 PR 验证)
       ├── tester   (写测试 + 集成测试 + raw stdout 验证)
       └── docs     (写 .md + 跟 cheatsheet 对照验证)
```

**容量**: 1 master 横向管 4 sub-roles (1+4 = 5 个并发 subagent)

---

## Conductor (我自己, 在主 session)

**职责**:
- 分析需求 + 拆解 ticket
- 审核 Performer PR
- 合并 feature → testing
- 发布 testing → miao (promote)
- 监控 Performer 心跳 + 派单

**分支权限**:
- miao: ✅ 只读分析 (可 review, 不可 commit)
- testing: ✅ merge
- feature/*: ❌ (那是 Performer 的工作)

**写代码**: ❌ 禁止 (跟 Performer 边界硬切, Rule 13)

**入口命令**:
```bash
kallax conductor:heartbeat         # Conductor 5 问
kallax conductor:dispatch TICKET   # 派 ticket 给 Performer
kallax conductor:review TICKET     # 审核 Performer PR
kallax conductor:merge TICKET      # merge feature → testing
```

---

## Performer (4 sub-roles)

**职责**: 领取 ticket + 开发 + 测试 + 提交 PR (在独立 worktree 中)

**分支权限**:
- feature/*: ✅ 开发 (worktree 隔离)
- miao: ❌
- testing: ❌

**写代码**: ✅ (在 feature worktree 中, Rule 14 强制隔离)

**入口命令**:
```bash
kallax performer:claim TICKET-001          # 领 ticket (自动建 worktree)
kallax performer:complete TICKET-001       # 完工 (5 步流程)
kallax performer:poll                      # 轮询派单
```

### 4 sub-roles (1+4 容量)

#### coder (默认, 写代码 + commit)

**职责**:
- 实施 ticket AC
- 写 commit (分步 commit, 不 1 PR 全塞)
- 跑 3 anti-fab (test-case-isolation / kpi-precision / scope-creep)

**关键约束**:
- Rule 5/8 类型安全 + Rule of 500
- PR ~100 行 (单 PR 粒度)
- 净变更 ≤ 500 行 (commit 粒度)

**入口命令**:
```bash
kallax performer:claim TICKET-001 --sub-role=coder
```

#### reviewer (审 PR + A/B review + 跨 PR 验证)

**职责**:
- A 组 (Forward): AC 合规 + 代码质量 + 集成
- B 组 (Attack): 安全 + 边界 + 攻击面
- 跨 PR 验证 (跟其他 reviewer 独立审)

**关键约束**:
- Rule 8 5-Level Fact-Forcing (L1-L5)
- Rule 18 KPI falsification 黑名单

**入口命令**:
```bash
kallax performer:claim TICKET-001 --sub-role=reviewer
```

#### tester (写测试 + 集成测试 + raw stdout 验证)

**职责**:
- 写单元测试 + 集成测试
- 跑 raw stdout (反 "should work" 估数)
- 维护 test fixture (跟 eket test fixture 模式 一致)

**关键约束**:
- Rule 9 anti-fab (test case verbatim = FAIL)
- Rule 8 L2/L4 强制 raw stdout

**入口命令**:
```bash
kallax performer:claim TICKET-001 --sub-role=tester
```

#### docs (写 .md + 跟 cheatsheet 对照验证)

**职责**:
- 写 .md (新文档 / 更新现有文档)
- 跟 docs/CHEATSHEET.md 对照验证 (反 narrative 包装)
- docs/CHEATSHEET.md ≤ 30 行 (硬约束)
- lazy load 文档 100-200 行 OK (5-levels / 4-roles 模式)

**关键约束**:
- Rule 5 DRY (Single Source of Truth)
- Rule 19 5 类标签 SOP (引用带证据链)
- 0 装饰引用 (无 evidence-chain 装饰)

**入口命令**:
```bash
kallax performer:claim TICKET-001 --sub-role=docs
```

---

## 1+4 容量 (跟单 master 横向)

```
master (1)
  │
  ├─── Performer A: coder TICKET-001 ────→ commit → PR
  ├─── Performer B: tester TICKET-002 ───→ test → raw stdout
  ├─── Performer C: reviewer TICKET-003 ──→ A/B review
  └─── Performer D: docs TICKET-004 ──────→ .md → cheatsheet 验证
```

**关键属性**:
- 4 sub-roles 并行 (worktree 隔离, Rule 1)
- 1 ticket = 1 sub-role (sub-role 是 session-level 锁定, Rule 15)
- L4 跨 PHASE 强制 sub-role reset (handoff_depth=L4, Rule 15)

---

## 分支管线

```
feature/<name> ──merge──→ testing ──promote──→ miao
 (Performer 开发)      (集成测试)      (Conductor 发布)
```

| 分支 | 谁能写 | 谁能 merge | 谁能 review |
|------|--------|------------|-------------|
| miao | ❌ (git hook 保护) | Conductor (promote) | Conductor (只读分析) |
| testing | ❌ | Conductor (merge feature→testing) | Conductor |
| feature/* | Performer (worktree) | Conductor (merge→testing) | Conductor + Performer/reviewer |

---

## 跟 eket 角色区别

| 维度 | eket | KALLAX |
|------|------|--------|
| **角色数** | 2 (Master + Slaver) | 4 (Conductor + Performer/coder+reviewer+tester+docs) |
| **层次** | 2 层 (Master-Slaver) | 3 层 (master → Conductor/Performer → sub-role) |
| **sub-role** | 1 (Slaver 单角色) | 4 (coder/reviewer/tester/docs 显式 enum) |
| **worktree** | 隐式 | 显式 (Rule 14 强制) |
| **分支权限** | 简化为 Master | 3 档 (miao/testing/feature) |
| **handoff** | task:handoff | handoff_depth L1-L4 (Rule 15) |
| **决策权** | 1 模式 (Master 拍) | 3 模式 (ai-auto / ai-copilot / manual) |

**结论**: KALLAX = 3 层 (master → Conductor/Performer → sub-role) + 4 sub-roles 并行 (1+4 容量), 跟 eket 2 层 (Master-Slaver) 区分. 借 eket multi-agent 概念, 不借 eket 角色设计 (1+4 vs 1+1 是核心差异).
