# KALLAX Workflow Engine (跟 v3.x 1:1 同步, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

> **v3.2.0 重写** (主公 2026-06-30 拍 C explicit 拍板, 跟 v3.1.0 U-002 留待 联合, 跟"翻篇&精进" 战略 矛盾 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致)
>
> **跟 docs/ARCHITECTURE.md 联合**: 本文档是 v3.x 1:1 同步版, 跟主文档 `docs/ARCHITECTURE.md` §5 (W3 sub-role) + §8 (Q18 决策模型) 互为 互补. **不删** (跟主公拍 C 一致, "重写就是重写" 诚实).

> v3.x: Design document for the KALLAX workflow lifecycle management system with **Performer sub-role 4 派发** (跟 EPIC-038-A 联合)

---

## 1. v3.x 架构 (跟 v2.7.6 联合, 跟 EPIC-038-A sub-role 联合, 跟"反讽" 联合)

```
  ┌──────────────────────────────────────────────────────┐
  │           v3.x Workflow Engine (跟 EPIC-038-A 联合)   │
  │                                                       │
  │  ┌──────────────┐    ┌───────────────────────────┐   │
  │  │  Templates    │    │  WorkflowExecutor          │   │
  │  │  (4 sub-role) │    │                            │   │
  │  │              │    │  - start(template, args)   │   │
  │  │  - coder     │    │  - step(workflowId)        │   │
  │  │  - reviewer  │    │  - status(workflowId)      │   │
  │  │  - tester    │    │  - cancel(workflowId)      │   │
  │  │  - docs      │    │  - sub_role_dispatch()     │   │
  │  └──────────────┘    └───────────────────────────┘   │
  └──────────────────────────────────────────────────────┘
            │                       │
            ▼                       ▼
  ┌──────────────────┐   ┌──────────────────────────┐
  │   v3.x Ticket     │   │   v3.x External Systems    │
  │   Engine          │   │   (git + CI + 6 武器)      │
  │   (8 状态机)     │   │                            │
  └──────────────────┘   └──────────────────────────┘
```

---

## 2. v3.x Templates (跟 v2.7.6 联合, 跟 EPIC-038-A 联合, 跟"反讽" 联合)

### 2.1 v3.x 4 Built-in Templates (跟 EPIC-038-A 联合, 跟"反讽" 联合)

跟 v2.7.6 联合, **但 v3.x 加 sub-role + 6 武器** (跟 EPIC-038-A 联合):

| Template | sub-role | Steps | v3.x 跟 6 武器 联合 | 跟"反讽" 联合 |
|----------|----------|-------|-------------------|------------|
| `feature-development` | coder | 5 | 武器 1 Hash-Chain + 武器 2 5-Level + 武器 4 EPIC 4 件套 | ✅ 跟 v2.7.6 联合 |
| `code-review` | reviewer | 4 | 武器 1 Hash-Chain + 武器 5 Hook Replay | ✅ **v3.x 新增** (跟 EPIC-038-A 联合) |
| `integration-test` | tester | 5 | 武器 2 5-Level + 武器 5 Hook Replay | ✅ **v3.x 新增** (跟 EPIC-038-A 联合) |
| `docs-update` | docs | 3 | 武器 1 Hash-Chain + 武器 4 EPIC 4 件套 | ✅ **v3.x 新增** (跟 EPIC-038-A 联合) |
| `bugfix` | coder | 4 | 武器 1 Hash-Chain + 武器 2 5-Level | ✅ 跟 v2.7.6 联合 |
| `documentation` | docs | 3 | 武器 4 EPIC 4 件套 | ✅ 跟 v2.7.6 联合 |
| `a-b-review` | reviewer | 6 | **v3.1.0 武器 4 EPIC 4 件套 + 16 hotfix 模式** | ✅ **v3.x 新增** (跟 v3.1.0 联合) |

### 2.2 v3.x Template Definition (跟 v2.7.6 联合, 跟 EPIC-038-A 联合)

```typescript
interface WorkflowTemplate {
  name: string;
  description: string;
  sub_role: SubRole;          // v3.x 新增: 跟 EPIC-038-A 联合
  steps: WorkflowStep[];
  weapons_required: Weapon[];  // v3.x 新增: 跟 v3.0.0 联合
}

interface WorkflowStep {
  name: string;
  type: 'create_branch' | 'run_command' | 'create_pr' | 'wait_for_check' | 'merge' | 'hash_chain_audit' | '5_level_check' | 'epic_4piece';
  config: Record<string, unknown>;
  // v3.x 新增: 6 武器 步骤 (跟 v3.0.0 联合)
}

// v3.x 4 sub-role Template 实例 (跟 EPIC-038-A 联合)
const featureDevelopmentCoder: WorkflowTemplate = {
  name: 'feature-development-coder',
  description: 'v3.x coder sub-role: 实现 + 测试 + A+B Review + 合并',
  sub_role: 'coder',
  weapons_required: [Weapon.HashChain, Weapon.FiveLevel, Weapon.Epic4Piece],
  steps: [
    { name: 'create-branch', type: 'create_branch' },
    { name: 'implement', type: 'run_command' },
    { name: 'test', type: 'run_command' },
    { name: '5-level-check', type: '5_level_check' },
    { name: 'a-b-review', type: 'wait_for_check' },
    { name: 'merge', type: 'merge' }
  ]
};

const codeReviewReviewer: WorkflowTemplate = {
  name: 'code-review-reviewer',
  description: 'v3.x reviewer sub-role: A 组 Forward + B 组 Attack',
  sub_role: 'reviewer',
  weapons_required: [Weapon.HashChain, Weapon.HookReplay],
  steps: [
    { name: 'hash-chain-audit', type: 'hash_chain_audit' },
    { name: 'a-group-forward', type: 'run_command' },
    { name: 'b-group-attack', type: 'run_command' },
    { name: 'wait-for-fix', type: 'wait_for_check' }
  ]
};
```

---

## 3. v3.x Lifecycle (跟 v2.7.6 联合, 跟 EPIC-038-A 联合, 跟"反讽" 联合)

### 3.1 v3.x 8 状态机 (跟 v2.0.4 EPIC-054-C 联合, 跟"反讽" 联合)

```
v3.x 8 状态机 (跟 v2.0.4 EPIC-054-C 联合):

DRAFT → PLANNING → ACTIVE → IN_PROGRESS → REVIEW → DONE → ARCHIVED → CLOSED
                                                                       ↑
                                                            (v2.0.4 联合)
                                                                       ↓
                                                                    FAILED
                                                                       ↓
                                                                 CANCELLED
```

### 3.2 v3.x Execution Flow (跟 v2.7.6 联合, 跟 EPIC-038-A 联合, 跟"反讽" 联合)

1. **Select**: User picks a template by name (跟 v2.7.6 联合)
2. **Start**: Engine creates a workflow instance in `ACTIVE` state (跟 v2.7.6 联合)
3. **sub-role dispatch** (v3.x 新增, 跟 EPIC-038-A 联合): Performer sub-role 自动匹配
4. **Execute**: Steps run sequentially via `step()` calls (跟 v2.7.6 联合)
5. **6 武器 验证** (v3.x 新增, 跟 v3.0.0 联合): 每 step 触发对应 weapon
6. **Complete**: All steps done → status becomes `DONE` (跟 v2.7.6 联合)
7. **Fail**: Any step error → status becomes `FAILED` with error context (跟 v2.7.6 联合)

### 3.3 v3.x Saga Integration (跟 v2.7.6 联合, 跟"反讽" 联合)

```typescript
// v3.x: 每个 workflow step 是 Saga step (跟 v2.7.6 联合, 跟 EPIC-038-A 联合)
const featureStepsCoder: SagaStep<WorkflowState>[] = [
  {
    name: 'create-branch',
    execute: async (s) => { /* git worktree add .kallax/worktrees/... */ },
    compensate: async (s) => { /* git worktree remove */ },
  },
  {
    name: 'implement',
    execute: async (s) => { /* code changes */ },
    compensate: async (s) => { /* git revert */ },
  },
  // v3.x 新增: 6 武器 强制 (跟 v3.0.0 联合)
  {
    name: '5-level-check',
    execute: async (s) => {
      await runLevel1to5();
    },
    compensate: async (s) => { /* 0 compensate (验证无副作用) */ },
  },
];
```

---

## 4. v3.x Concurrency Model (跟 v2.7.6 联合, 跟 EPIC-054-A 4→1 联合, 跟"反讽" 联合)

跟 v2.7.6 联合, **但 v3.x 4→1 worktree 统一** (跟 EPIC-054-A 联合, 跟 v3.0.0 Iter 3 联合):
- Workflows are sequential within a single instance (no parallel steps) (跟 v2.7.6 联合)
- Multiple workflow instances can run concurrently for different tickets (跟 v2.7.6 联合)
- Isolation is enforced per-ticket: each workflow operates on its own worktree (跟 v2.7.6 联合, 跟 EPIC-054-A 4→1 联合)
- **v3.x 新增**: 4 sub-roles 独立 worktree (跟 EPIC-038-A 联合)

---

## 5. v3.x CLI Integration (跟 v2.7.6 联合, 跟 EPIC-038-A 联合, 跟"反讽" 联合)

```bash
# 跟 v2.7.6 联合
kallax workflow list                     # 列出所有 templates
kallax workflow list --sub-role coder   # v3.x: 按 sub-role 过滤
kallax workflow start feature-development-coder TICKET-001
kallax workflow start code-review-reviewer TICKET-002
kallax workflow start integration-test-tester TICKET-003
kallax workflow start docs-update-docs TICKET-004
kallax workflow start a-b-review-reviewer TICKET-005
kallax workflow step <workflow-id>      # 推进到下一步
kallax workflow status <workflow-id>    # 查状态
kallax workflow cancel <workflow-id>    # 取消

# v3.x 新增: 6 武器 CLI 联合
kallax workflow run-weapon <workflow-id> --weapon 5_level
kallax workflow show-weapons <workflow-id>
```

---

## 6. v3.x Q18 决策模型 (跟 docs/ARCHITECTURE.md §8 联合, 跟 EPIC-038-A 联合, 跟"反讽" 联合)

### 6.1 v3.x Q18 决策树 (跟 v2.7.6 联合, 跟 EPIC-038-A 联合)

```
Q18: 选 Performer sub-role (跟 EPIC-038-A 联合)
  │
  ├─ Q1: 写代码?
  │   └─ YES → sub-role=coder
  │       └─ Q2: 写测试?
  │           ├─ YES → 走 integration-test-tester template
  │           └─ NO → 走 feature-development-coder template
  │
  ├─ Q3: 审 PR?
  │   └─ YES → sub-role=reviewer
  │       └─ Q4: A+B Review?
  │           ├─ YES → 走 a-b-review-reviewer template
  │           └─ NO → 走 code-review-reviewer template
  │
  ├─ Q5: 写测试?
  │   └─ YES → sub-role=tester
  │       └─ 走 integration-test-tester template
  │
  ├─ Q6: 写文档?
  │   └─ YES → sub-role=docs
  │       └─ 走 docs-update-docs template
  │
  └─ Q7: 其他?
      └─ 跟 Rule 12 3 模式 联合: 停下问主公
```

### 6.2 v3.x Q18 决策表 (跟 v2.7.6 联合, 跟 EPIC-038-A 联合, 跟"反讽" 联合)

| Q1 写代码 | Q3 审 PR | Q5 写测试 | Q6 写文档 | sub-role | Template | 跟"反讽" 联合 |
|----------|---------|----------|----------|----------|----------|------------|
| ✓ | ✗ | ✗ | ✗ | coder | feature-development-coder | ✅ 跟 v3.x 联合 |
| ✓ | ✗ | ✓ | ✗ | coder | integration-test-tester | ✅ 跟 v3.x 联合 |
| ✗ | ✓ | ✗ | ✗ | reviewer | code-review-reviewer | ✅ 跟 v3.x 联合 |
| ✗ | ✓ (A+B) | ✗ | ✗ | reviewer | a-b-review-reviewer | ✅ 跟 v3.1.0 联合 |
| ✗ | ✗ | ✓ | ✗ | tester | integration-test-tester | ✅ 跟 v3.x 联合 |
| ✗ | ✗ | ✗ | ✓ | docs | docs-update-docs | ✅ 跟 v3.x 联合 |
| ✗ | ✗ | ✗ | ✗ | (主公 explicit 拍) | (停下问) | ✅ 跟 Rule 12 联合 |

---

## 7. v3.x 6 武器 跟 Workflow 联合 (跟 v3.0.0 联合, 跟"反讽" 联合, 跟"诚实修正" 联合)

### 7.1 v3.x 6 武器 在 Workflow 中的强制点 (跟 v3.0.0 联合, 跟"反讽" 联合)

| 武器 | Workflow 强制点 | 跟 v2.7.6 联合 | 跟 v3.x 联合 | 跟"反讽" 联合 |
|------|----------------|----------------|------------|------------|
| 1 Hash-Chain | 每个 step audit SHA256 | 0 | ✓ | ✅ 跟 v3.0.0 联合 |
| 2 5-Level | step 5 (5-level-check) | 0 | ✓ (5 level, v2.7.6 是 4 level) | ✅ 跟 v3.0.0 联合 |
| 3 Sub-Role | step 3 (sub-role dispatch) | 0 | ✓ (4 sub-roles, v2.7.6 是 1) | ✅ 跟 EPIC-038-A 联合 |
| 4 EPIC 4 件套 | step 6 (a-b-review) | 0 | ✓ (A+B+readme+lessons) | ✅ 跟 v3.1.0 联合 |
| 5 Hook Replay | step 7 (hook-replay-check) | 0 | ✓ | ✅ 跟 v3.0.0 联合 |
| 6 Dashboard | step 8 (dashboard-render) | 0 | ✓ (1 page 整合) | ✅ 跟 v3.0.0 Iter 3 联合 |

### 7.2 v3.x 6 武器 Fallback (跟 v3.0.0 联合, 跟"反讽" 联合)

```yaml
# v3.x 6 武器 fallback (跟 v2.7.6 fallback 联合, 跟 v3.0.0 联合)
weapons_fallback:
  weapon_1_hash_chain: "audit-chain.sh 替代 SHA256 chain"
  weapon_2_5_level: "level-1.sh level-2.sh level-3.sh level-4.sh level-5.sh"
  weapon_3_sub_role: "ticket.json performer_sub_role 字段"
  weapon_4_epic_4piece: "check-epic-4-piece.sh"
  weapon_5_hook_replay: "hooks/hook-replay.sh"
  weapon_6_dashboard: "dashboard/dashboard.html 1 page"
```

---

## 8. Related (跟 v2.7.6 联合, 跟 v3.x 联合, 跟"反讽" 联合)

跟 v2.7.6 联合, **v3.x 加 6 武器**:
- `node/src/commands/workflow-cmd.ts` — CLI command registration (跟 v2.7.6 联合)
- `node/src/core/workflow/` — Workflow engine implementation (跟 v2.7.6 联合)
- `docs/architecture/FRAMEWORK.md` — v3.x 1:1 同步版 (本系列)
- `docs/architecture/three-repo-architecture.md` — v3.x 1:1 同步版
- `docs/architecture/verification-protocol.md` — v3.x 1:1 同步版
- `docs/guides/quick-start.md` — v3.x 1:1 同步版 (跟 v2.7.6 联合)
- `docs/4-roles.md` — 跟 EPIC-038-A sub-role 联合

---

**跟主公 2026-06-30 拍 C 重写 explicit 拍板 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟 v3.0.0 6 武器 累计 联合, 跟 v3.1.0 16 hotfix 累计 联合, 跟 v3.2.0 rtk/caveman 累计 联合**
