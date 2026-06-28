# KALLAX 权限分级方案 — Tiered Permission System

**Created**: 2026-06-07
**Status**: Design Complete — awaiting Conductor/Master approval
**Author**: KALLAX Expert Panel (Architect + Backend + Frontend + UX + Product)
**Scope**: 全局,影响 master/conductor/performer 全部 role,以及 21 个 CLOSING 残留 instance
**Source**: `confluence/decisions/PERMISSION-PANEL-RAW-2026-06-07.md` (5 专家完整原始输出)

---

## 1. Strategy (策略)

### 1.1 模型选择:RBAC + ReBAC 混合

| 层 | 模型 | 覆盖 |
|---|---|---|
| 顶层 | **RBAC** | role → grants(master/conductor/performer/auditor/readonly/super-admin/emergency-responder) |
| 资源层 | **ReBAC** | ticket → file_scope(EPIC-016-J 只可触 jira/tickets/EPIC-016-J/** + worktree) |
| 属性层 | **ABAC-lite** | TTL / branch gate / instance_status(active/stale/closing) |

**否决**:
- ❌ 纯 ACL:21+ instance 维护成本爆炸
- ❌ 纯 ABAC:每条规则都要 evaluator,MVP 周期装不下
- ✅ ReBAC 因为 `ticket.json.file_scope` 已经是天然资源图

### 1.2 角色路线图(4 周 MVP)

```
Week 1  Week 2  Week 3  Week 4
  │       │       │       │
  ├── readonly (P0)─────────┤  零风险,纯加
  ├── performer + ticket-scope (P0)─┤  现有增强
  ├── conductor delegation TTL (P1)─┤  master → conductor 委托
  ├── auditor (P1)──────────────────┤  只读 + 审计
  ├── super-admin (P2)──────────────┤  改 permissions.yml
  └── emergency-responder (P2)──────┘  接管 stale instance
```

**优先级理由**:
1. **readonly** 0 冲突,纯加 — 先发
2. **ticket-scoped grants** 解决 P0「performer 误触其他 worktree」 — 已存在的 scope 字段正式化
3. **delegation TTL** 解决「master 离线时 conductor 无 merge 权限」— 紧急 hotfix 场景
4. **auditor** 解决 EPIC-016 production system 合规
5. **super-admin + emergency-responder** 解决 21 CLOSING 残留 + permissions.yml 运行时改

### 1.3 委托 vs 一次性 — 决策

**默认 ticket-scoped,break-glass = session-scoped**(三专家共识):

| 类型 | 粒度 | TTL | 用途 |
|---|---|---|---|
| **Ticket Grant**(默认) | 单 ticket + file_scope | 任务 TTL(2h) | 「performer 拿到 publish 权限」 |
| **Session Delegation** | 整个 session | 1h/4h/shift | 「master 委托 review 1 天」 |
| **Break-Glass** | 单 action + 强审计 | ≤ 1h + auto-revoke | 「2am hotfix miao」 |

---

## 2. 实现方法

### 2.1 分层架构

```
┌──────────────────────────────────────────────────────────┐
│  Layer 0: User(developer)                                │
│      ↓ CLI:  kallax permission:*                         │
│      ↓ NL:   "/kallax give performer read on docs/"      │
├──────────────────────────────────────────────────────────┤
│  Layer 1: CLI 入口  scripts/permission/*.sh              │
│      grant / revoke / list / check / explain / break-glass│
├──────────────────────────────────────────────────────────┤
│  Layer 2: 鉴权内核  lib/authz/                            │
│      check.sh --actor <id> --action <a> --resource <r>    │
│      ├── rbac.sh    (role → grants, O(1) assoc array)    │
│      ├── rebac.sh   (ticket → file_scope 校验)            │
│      └── audit.sh   (异步 append 到 .kallax/data/authz.db)│
├──────────────────────────────────────────────────────────┤
│  Layer 3: 持久化  .kallax/data/kallax.db(WAL 模式)        │
│      authz_roles / authz_grants / authz_audit            │
├──────────────────────────────────────────────────────────┤
│  Layer 4: 强制拦截  已有 hooks(扩展)                       │
│      pre-commit  ←→  authz/check.sh --action miao.write   │
│      session_start  ←→  加载 role + 失效 cache            │
│      heartbeat-daemon  ←→  60s invalidate 触发          │
└──────────────────────────────────────────────────────────┘
```

**Hot path 性能预算 < 10ms**:
```
RBAC lookup:    ~0.1ms (in-memory assoc array)
TTL check:      ~0.1ms
ReBAC scope:    ~0.5ms (realpath + prefix match)
Audit write:    ~0ms   (non-blocking, queue)
─────────────────────
Total:          ~0.7ms ✓
```

### 2.2 关键文件清单

| 文件 | 状态 | 用途 |
|---|---|---|
| `lib/authz/check.sh` | 新建 | 鉴权入口,被 hook/CLI 调用 |
| `lib/authz/rbac.sh` | 新建 | 角色 → grants 查找 |
| `lib/authz/rebac.sh` | 新建 | ticket scope 校验,realpath 防 symlink 绕过 |
| `lib/authz/audit.sh` | 新建 | 异步写 audit 表 |
| `.kallax/config/authz.yml` | 新建 | 角色 + scope + grants schema |
| `scripts/permission/{grant,revoke,list,check,explain}.sh` | 新建 | CLI 表面 |
| `scripts/permission/break-glass.sh` | 新建 | 紧急覆盖 + 审计 |
| `.kallax/hooks/pre-commit` | 改 | 调用 `authz/check.sh` 在文件写入前 |
| `.kallax/hooks/session_start.sh` | 改 | 加载 role + 失效 cache |

### 2.3 schema 示例(`authz.yml`)

```yaml
roles:
  master:       { inherits: conductor, grants: [miao.write, miao.merge, release.tag, instance.gc] }
  conductor:    { inherits: null,     grants: [testing.merge, testing.write, task.assign] }
  performer:    { inherits: null,     grants: [task.claim, worktree.create, worktree.commit] }
  readonly:     { inherits: null,     grants: [*.read] }
  auditor:      { inherits: readonly, grants: [audit.export] }
  super-admin:  { inherits: master,   grants: [authz.modify, emergency.override] }
  emergency-responder: { inherits: super-admin, grants: [instance.terminate] }

scope_bindings:
  EPIC-016-J:
    allowed_paths: ["jira/tickets/EPIC-016-J/**", ".kallax/worktrees/**/EPIC-016-J/**"]
    ttl_seconds: 7200

action_grants:
  - id: perm_001
    role: performer
    action: publish.npm
    ticket: EPIC-016-P
    granted_by: conductor_StevendeMacBook-Pro.local_28000
    granted_at: "2026-06-07T10:00:00Z"
    expires_at: "2026-06-07T12:00:00Z"   # 2× heartbeat
    status: active
```

---

## 3. 约束矩阵(硬 vs 软)

> 升级原则:每条软约束都必须有明确的「硬化路径」,否则就是债务。

| 规则 | 当前 | 目标 | 升级路径 |
|---|---|---|---|
| Conductor 不可写 miao | 软(CLAUDE.md) | **硬** | pre-commit hook → `authz/check.sh --action miao.write --actor conductor` |
| Performer 不可 merge | 软 | **硬** | pre-commit + `gh pr merge` 前置 check |
| Performer 仅在 worktree | 软 | **硬** | session_start.sh 检查 `cwd` ∈ `worktree/...` |
| Skill 调用无隔离 | 软 | **半硬** | `authz/check.sh` 包裹 Skill 工具调用(Week 3) |
| Cross-instance inbox | 软(目录隔离) | **硬** | ReBAC: 只有 `to: <self>` 的 inbox 消息可读 |
| Heartbeat daemon self-protection | 软 | **硬** | session_start.sh EXIT trap + `instance.gc` 自动复活 |
| 21 CLOSING 残留 | 软(check-stale.sh) | **硬** | cron: 5min 超时 → `instance.terminate` 自动 GC |
| Break-glass 覆盖 | 无 | **硬 + 强审计** | 单独 action,全 audit,TTL ≤ 1h |
| Multi-role 冲突 | 无 | **硬** | 显式 `kallax role:set` 切换,默认 most-permissive wins |
| Permission service 降级 | 无 | **硬** | cache 5min → 超时 deny,不静默 allow |

### 软约束保留区(产品决策:不强硬化)

| 规则 | 为什么软 |
|---|---|
| 「Conductor 不应该做 performer 工作」 | 文化约束,机器检测易误报;靠 code review + audit |
| 「Performer 写代码要 TDD」 | 流程约束,git hook 难判定;靠 PR review + 报告 |
| 「注释不要写废话」 | 代码风格,机械化成本高;靠 lint + 评审 |
| 命名规范(magic number 等) | 同上,留给 review |

---

## 4. 决策清单(7 条,Conductor 仲裁)

| # | 决策 | 共识 | 反对 |
|---|---|---|---|
| 1 | 模型 = RBAC + ReBAC | 4/4 | — |
| 2 | 鉴权层 = 新建 `lib/authz/`,不扩展 daemon.sh | Backend + Architect | — |
| 3 | 持久化 = 复用 `.kallax/data/kallax.db` | Backend | Product 倾向独立文件(可接受) |
| 4 | 入口 = CLI 优先,NL 确认回退 | Frontend + UX | — |
| 5 | 心智模型 = 树形(role→scope→action) | Frontend + UX | — |
| 6 | MVP = 18 days,4 周 rollout(Shadow→Warn→Hard) | Product | — |
| 7 | Break-glass ≤ 2min,TTL ≤ 1h,全 audit | UX + Product | — |

---

## 5. 关键风险(7 条)

| # | 风险 | 概率 | 缓解 |
|---|---|---|---|
| 1 | `lib/authz/` 被 performer 改 → bypass | M | `scripts/authz/` 加 pre-commit ALLOWED_PATTERNS(Backend R1) |
| 2 | ReBAC symlink 路径绕过 | M | realpath + 前缀匹配,reject 越界(Backend R2) |
| 3 | 60s cache 内 rapid grant/revoke 失效窗口 | M | grant/revoke 写 FIFO,daemon 读 FIFO 立即失效(Backend R3) |
| 4 | Hard 切换中断 active work | H | Shadow W1-2 + whitelist active worktree + `--permissions=soft` flag(Product R1) |
| 5 | 21 CLOSING migration 期间泄漏 | H | 预清理脚本 + 监控 > 5 告警(Product R2) |
| 6 | TTL clock skew | M | epoch + bash `date +%s`,每次 check 重验(Product R3) |
| 7 | Permission service 不可达 → deny 阻塞 hotfix | M | cache 5min + 显式 `KALLAX_EMERGENCY_MODE=super-admin` 旁路 + 全 audit(UX §6) |

---

## 6. Action Items(4 周时间表)

| Week | Items |
|---|---|
| **W1** | ① 起草 `.kallax/config/authz.yml` schema ② 建 `lib/authz/{check,rbac,rebac,audit}.sh` stub ③ 加 `authz_roles/grants/audit` SQLite 表 ④ Shadow mode 日志(只 log,不 block) |
| **W2** | ⑤ `kallax permission:{grant,revoke,list,check,explain}.sh` CLI ⑥ pre-commit 调用 `authz/check.sh` ⑦ 迁移 21 CLOSING instances(预清理) ⑧ Auditor role 上线 |
| **W3** | ⑨ ReBAC ticket-scope 强制 ⑩ 改 session_start.sh 加 `cwd ∈ worktree/` 校验 ⑪ Break-glass + audit FIFO ⑫ 软→Warn mode 切换 |
| **W4** | ⑬ 软→Hard mode 切换 ⑭ 5 个 KPI 仪表盘 ⑮ emergency-responder role ⑯ `--permissions=soft` 旁路 flag ⑰ 文档 + onboarding |

**总投入:18 人天(3 engineers:1 conductor + 2 performer)**,与 EPIC-016 平行不冲突。

---

## 7. 5 个 KPI(v1 验收)

| KPI | 目标 | 测量 |
|---|---|---|
| M1 零越权写 miao | 100% 拦截 | `grep "FORBIDDEN.*conductor.*write.*miao" .kallax/logs/*.jsonl` = 0 |
| M2 Delegation TTL 100% auto-expire | 100% | 实际 grants vs `expires_at` 对账无 stale |
| M3 CLOSING 残留 | < 2 instances | `find .kallax/instances -name state.json \| jq .status \| grep -c CLOSING` < 2 |
| M4 新 role 采纳 | 4/4 roles ≥ 1 active instance within 2 weeks | instance registry 统计 |
| M5 Authz check P99 latency | < 10ms | `.kallax/logs/permission_checks.jsonl` timing |

---

## 8. 灵感来源(避免/借鉴)

| 系统 | 借鉴 | 避免 |
|---|---|---|
| **AWS IAM** | TTL-based temporary credentials,policy as code | 200+ permission type 复杂度 |
| **Kubernetes RBAC** | RoleBinding vs ClusterRoleBinding(ticket-scoped vs global),`kubectl auth can-i` | K8s verb 模型不直接对应 kalloax 操作 |
| **GitHub Branch Protection** | Required reviewers,admin bypass 显式 opt-in | 单一 admin override 风险 |
| **Google Zanzibar** | Real-time check,immutable audit | v1 不需要 fan-out 图 |

---

## 9. 待 Conductor/Master 决策

- [ ] **Approve** 模型 (RBAC + ReBAC)
- [ ] **Approve** 4 周时间表(W1-W4)
- [ ] **Decide** 是否建 EPIC-017 跟踪 6 tickets
- [ ] **Decide** 与 EPIC-016 是否平行(不冲突)还是延后
- [ ] **Decide** Phase 0 (本周) 是否先 patch EPIC-016-O (CLOSING GC) 作为前导

---

**Raw input**: `confluence/decisions/PERMISSION-PANEL-RAW-2026-06-07.md`
**Last updated**: 2026-06-07
**Reviewer(s)**: master_main, conductor_StevendeMacBook-Pro.local
