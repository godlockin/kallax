# Permission Model — 5 Expert Panel Review 综合分析报告

**Date**: 2026-06-07
**Reviewers**: Architect + Backend + Security + DevOps + Product (5 experts, parallel dispatch)
**Source docs**: `confluence/decisions/PERMISSION-MODEL.md` + `PERMISSION-PANEL-RAW-2026-06-07.md`
**Context**: EPIC-016 postmortem 经验教训 (session_start.sh 卡死事件)

---

## 0. 背景与历史教训

### EPIC-016 关键事件 (postmortem 引用)

1. **session_start.sh 永久卡死** — 1+ 天修复, root cause: 后台进程 stdio 重定向丢失 + Node.js spawn 等待 fd 关闭 + 100% 静默错误
2. **Performer 误路由** (R + N) — 直接写 miao, 误删 M/S 优化注释
3. **O 安全 review** — 5 issue (3 HIGH + 2 MEDIUM) 修复后又标 5 issue
4. **Pre-commit hook 盲点** — 不允许 jira status 改动, 迫使 --no-verify
5. **Performance 隐性回归** — 性能优化导致 cold wall_time 退化 13%

### 本评审核心问题

Permission Model 涉及 18 days × 3 engineers + 4 周 rollout + 6 个新 role + 多文件分层 (authz/check/rbac/rebac/audit) + SQLite + FIFO + 4 阶段切换 (Shadow→Warn→Hard)。

**核心风险**: 是否会复现 session_start.sh 类的「脚本黑洞」?

---

## 1. 5 专家评审汇总

| 专家 | 评分 | 一句话核心 | P0 数 |
|---|---|---|---|
| **Architect** | YES (with P0 modifications) | 设计合理但 18d 偏乐观 (→ 22d), rollback SOP 缺失 | 2 |
| **Backend** | NO | bash hot path 实际 20-50ms (非 10ms), 4 脚本缺 `set -euo pipefail` | 6 |
| **Security** | NO | fail-open 是定时炸弹, authz.yml 篡改无防御, realpath 执行顺序未明 | 6 |
| **DevOps** | NO | O 10 issue 阻塞 W4 hard 切换, 测试时间 = 0 | 6 |
| **Product** | PARTIAL | 6 role 过多, 18d 应缩到 12-14d, F5 移 Phase 0, F1 升 P0 | 0 (re-balance) |

**综合评分: NO (4/5 反对, 1/5 需重大修改)**

---

## 2. 各专家详细发现

### 2.1 Architect (YES w/ P0 mods)

**架构合理性 (PARTIAL)**:
- RBAC+ReBAC 混合 ✓ 合理, 复用 `ticket.json.file_scope` 天然资源图
- 4 文件分层 (check/rbac/rebac/audit) 清晰, 但**遗漏 `lib/authz/cache.sh`**
- 60s TTL cache 逻辑散落在 daemon.sh 和 check.sh 之间, 隐藏耦合
- 4 周 rollout 节奏 ✓ 合理, 但 18 days 偏乐观 (EPIC-016 同预算仅完成 60% 目标)

**「脚本黑洞」风险 (P0/P1/P2)**:
- **P0** — FIFO cache invalidation 静默死锁: 若 daemon 在两次 heartbeat 之间 crash, FIFO 无人消费且无告警. **同 session_start.sh 根因**
- **P0** — ReBAC realpath 在 NFS/home 目录可能返回慢 (>5ms), 0.5ms 预算立刻击穿
- **P1** — SQLite WAL 高并发写, authz_grants TTL update 可能 retry loop
- **P1** — Hard switch 无 rollback procedure (`--permissions=soft` flag 存在但操作步骤未文档化)
- **P2** — 60s TTL cache 刚好覆盖 heartbeat, FIFO 自身单点

**实施性**:
- 18d → 22d buffer (+20%)
- W2 的 21 CLOSING migration 是 gating factor
- W3 session_start.sh cwd 校验 + W4 ReBAC realpath 是延期高风险

**7 风险评估 (R1-R7)**:
| # | 风险 | 评估 |
|---|---|---|
| R1 | lib/authz/ 被 performer 改 | ✅ 缓解, 但 scripts/authz/ 若 later 移入 worktree 范围则失效 |
| R2 | ReBAC symlink 路径绕过 | ✅ realpath + 前缀匹配标准, 但 `.kallax/` 外 symlink 无 reject |
| R3 | 60s cache 内 rapid grant/revoke | ✅ FIFO 设计正确, **但 FIFO 自身无 watchdog** |
| R4 | Hard 切换中断 active work | ⚠️ **无 hard→soft rollback 操作手册** |
| R5 | 21 CLOSING migration 泄漏 | ✅ 预清理 + 监控 >5, 但 check-stale.sh 自身是 soft check |
| R6 | TTL clock skew | ✅ epoch + tolerance 充分 |
| R7 | Permission service 不可达 | ✅ cache 5min + emergency, **但无 single-node SPOF 评估** |

**修改建议 (P0)**:
1. authz/check.sh 入口加 `set -o pipefail` + SIGTERM handler
2. FIFO 前加 `flock` 或容量检查
3. W3 前补充 **Hard→Soft rollback runbook**
4. (P1) 独立 `lib/authz/cache.sh`
5. (P1) realpath 加 timeout 保护

---

### 2.2 Backend (NO)

**实施性 (PARTIAL)**:
- **bash hot path 10ms 现实性: FAIL** — yq YAML 解析 5-20ms, realpath macOS 1-5ms, 多文件 source 解析漏算
- **现实估算: 20-50ms** (vs 目标 10ms)
- SQLite WAL: 无 `busy_timeout` → 锁等待无上限
- **FIFO 实现: FAIL** — `mkfifo` 权限受限, 未指定 `O_NONBLOCK`, **同 session_start.sh 卡死根因**

**「脚本黑洞」风险**:
- **P0** — audit.sh 写 FIFO 若 daemon 死 → check.sh hang → pre-commit hang → 全局卡死
- **P0** — audit 失败 → deny-by-default (符合 KALLAX P0 规则, 但未明确)
- **P1** — SQLite 锁竞争, pre-commit blocking sync 无 timeout
- **P2** — RBAC 文件损坏 fail-open 风险 (KALLAX P0 违规)

**错误处理 (PARTIAL)**:
- 4 个 authz 脚本均**未声明 `set -euo pipefail`** (KALLAX P0 违规)
- jq 不可用降级路径未定义
- 错误信息格式未定义 (无 request_id + stack trace)

**集成风险**:
- 21 CLOSING 迁移 SOP 风险未量化
- 19 EPIC-016 worktree hard 切换可能 break (`--permissions=soft` flag 存在但未在工作流强制)

**修复项 (P0)**:
1. audit.sh FIFO 改非阻塞 (`O_NONBLOCK` 或 background process)
2. 4 authz 脚本全部加 `set -euo pipefail`
3. SQLite 加 `timeout=5000` busy_timeout
4. audit 失败 deny-by-default (exit 1)
5. (P1) jq 不可用 deny
6. (P1) RBAC 文件损坏 deny
7. (P2) hot path 改 Python/Node

---

### 2.3 Security (NO)

**路径安全 (PARTIAL)**:
- macOS case-insensitive fs + symlink 组合可能产生意外 realpath
- 文档混用"glob"和"prefix match" — **glob `**` 匹配多层, prefix match 字符串比较无法防御 `EPIC-016-J/../EPIC-016-K/`**
- **realpath 执行顺序必须在前**, scope check 在后
- `.kallax/` 外 symlink 无 explicit reject, 建议加 `realpath -m` 校验

**RBAC 注入 (FAIL)**:
- **authz.yml 改写**: ALLOWED_PATTERNS 只控制 staged 文件, `git commit --no-verify` 或直接写文件可绕过
- **YAML 解析安全**: 未指定 parser, 若 `grep/awk` 解析 YAML value 存在 eval 风险
- **role 名称冲突**: 无限制, "conductor " (trailing space) 或 "mster" typo 无防御
- **循环继承检测**: `A inherits B, B inherits A` 会导致无限循环, 文档未提

**审计安全 (PARTIAL)**:
- audit.db 是 WAL SQLite, 非 append-only 文件 (superuser 可 DELETE)
- log injection: `printf "%s\n" "$line"` 拼接, jsonl 格式需 `"` escaping, 未提
- DoS 防护: 无 rate limit

**Break-Glass 滥用 (PARTIAL)**:
- bypass audit 风险: break-glass 路径若 authz check 失败, fail-open?
- self-approval: `KALLAX_EMERGENCY_MODE=super-admin` 旁路靠"人工检查"非技术强制
- TTL clock skew tolerance: 60s tolerance, 但 NTP drift > 60s 时可能未过期
- 无反复 break-glass rate limit

**并发攻击 (P1/P2)**:
- P1 — FIFO 写竞争 (多个 conductor 并行 revoke 可能丢事件)
- P1 — SQLite 锁竞争
- P2 — Cache race (SIGHUP invalidation window 30s 内 revoked permission 仍可使用)

**EPIC-016 复现风险**:
- **authz check hang**: 若 stdio 重定向缺失, `--actor` 会 block 在 stdin. 文档未要求 `< /dev/null` 兜底
- **fail-open 风险**: authz check 内部错误 (文件不存在, parser 失败) 返回 allow 还是 deny? 未明确
  - **EPIC-016-O cleanup.sh 就是错误时 return 0 导致逻辑反转**

**修复项 (P0)**:
1. realpath 执行顺序必须在前
2. authz.yml 防篡改保护
3. YAML parser 必须用安全实现, 禁止 eval
4. 循环继承检测必须实现
5. authz check 错误时必须 deny 而非 allow
6. FIFO 写需原子化或加锁
7. (P1) break-glass rate limit
8. (P1) audit append-only 实现
9. (P1) TTL clock skew tolerance 明确化

---

### 2.4 DevOps (NO)

**Rollout 现实性 (PARTIAL)**:
- 18 days 无测试时间拆解, 含集成测试几乎不可能
- Week 间依赖: W2 CLI 依赖 W1, W3 ReBAC 依赖 W2, W4 hard 依赖 W3. 无并行化空间
- Shadow mode 2 周不够发现边界 case (ReBAC symlink bypass 需要更长时间 replay)
- **Rollback 路径: 文档化缺失** — 只有 `--permissions=soft` flag, 无操作 SOP
- **O 5修 + 安全 5 issue 未列入 Action Items, 也未分配 EPIC-017 跟踪**

**可观测性 (PARTIAL)**:
- M1 用 grep 查 FORBIDDEN 日志, 只能检测**已发生**越权
- P99 < 10ms 测量: 文档无 CI gate 或 runtime probe
- 越权写检测: M1 只测 conductor→miao write, 其他越权 (performer→testing merge, cross-instance inbox) 无监控
- 无仪表盘设计

**运维 (FAIL)**:
- **Service down 策略**: 5min cache + full deny 合理, 但**无 SOP 文档**
- **21 CLOSING 迁移 SOP**: Phase 0 未定义具体 SOP
- **紧急 rollback 流程**: 完全缺失
- **多 repo 迁移**: 文档说"全局", 但无跨 KALLAX 安装的 migration plan

**测试 (FAIL)**:
- **测试时间占比: 0** (18 days 全是开发)
- Shadow replay 未设计 (用历史操作在 shadow 下验证)
- 模糊测试未提及
- 21 CLOSING 迁移 dry-run 未提及

**EPIC-016 关联 (PARTIAL)**:
- 现有 19 commits 在 hard mode 风险: session_start.sh EXIT trap 改 CLOSING 无 authz 检查
- performer 软禁止 (9 条) 在 hard mode 下 CLAUDE.md 其他软规则无 hook 保护
- **O 修复必须在 W4 hard 切换前完成, 但无 EPIC-017 跟踪 P0 修复项**

**修复项 (P0 阻塞 W4 hard 切换)**:
1. EPIC-017 跟踪 O 5项 + 安全 review 5 issue
2. 设计 rollback SOP (`--permissions=soft` 完整流程)
3. 21 CLOSING Phase 0 SOP (清理脚本 + 验证 + 监控阈值)
4. 测试时间拆解 (≥30%)
5. Shadow replay 设计
6. 实时告警 (audit log 流)
7. (P1) P99 latency CI gate
8. (P1) 多 repo 迁移 plan
9. (P1) 仪表盘设计

---

### 2.5 Product (PARTIAL)

**范围合理性 (PARTIAL)**:
- 6 role 数量: 3→7 (增幅 133%). 偏多
- **建议 v1 只做 readonly + auditor (2个)**, super-admin/emergency-responder 推 v2
- F5 CLOSING GC (2d) 应该 Week 0 提前做, 不应占 v1 时间
- 18 days 应缩到 12-14d

**优先级 (PARTIAL)**:
- 角色路线图顺序: readonly → auditor → super-admin → emergency-responder 逻辑正确
- **F1 Hard Role Enforcement 应升 P0** (多层防御, 唯一消除「conductor 误触生产」)
- F3 Delegation TTL: 真实痛点但 EPIC-016 已验证 master 参与度极高, 触发频率低于预估

**用户价值 (PARTIAL)**:
- 主要用户: conductor + master (写 miao 风险承担者)
- performer ticket-scope: 实际场景有限, F4 ReBAC 校验是纵深防御
- **5 KPI 重要性**: M1 (零越权写 miao) 最重要, M3 (CLOSING) 次之

**替代方案**:
- 仅强化 hook: 不够 (管不了 session_start/heartbeat/instance lifecycle)
- 仅 RBAC 不做 ReBAC: 基本够用, F4 推 v2
- 推迟 v2: **可接受** (当前 3 role 已运转, pre-commit hook 兜底)

**v1 推荐范围 (12-14 days, 聚焦高价值)**:
| 必做 (P0) | 推迟 v2 |
|-----------|---------|
| F1 Hard Role Enforcement | F2 super-admin + emergency-responder |
| readonly (Week 1) | F4 ReBAC scope (RBAC-only 够用) |
| F3 Delegation TTL | F5 → Week 0 预清理 |
| Auditor role (合规) | |

**核心建议**:
1. F5 移出 v1 (Week 0 前导)
2. F4 ReBAC 推 v2
3. super-admin/emergency-responder 推 v2
4. F1 升 P0 无条件
5. O 安全 5 issue 修完后再切 Hard mode

---

## 3. 「脚本黑洞」复现风险分析 (跨专家汇总)

| 类似 session_start.sh 模式 | Permission Model 对应 | 风险等级 | 缓解 |
|---|---|---|---|
| 启动期后台进程 stdio 继承 | authz.sh 内部派生子进程 (jq 解析, FIFO 写) | **P0** | 文档未规定 `< /dev/null` 兜底 |
| Producer 写 pipe 无 consumer | grant/revoke 写 FIFO, daemon 死时无人消费 | **P0** (同根因) | **无 watchdog 检测 FIFO 写入无应答** |
| Hot path 性能炸裂导致 hang | bash hot path 实际 20-50ms (vs 目标 10ms) | **P0** | 改 Python/Node |
| Pre-commit hook 错误 fail-open | authz check 错误时 allow vs deny? | **P0** | 必须 deny-by-default |
| Soft 约束变硬约束时漏改 | soft→hard 切换时 19 EPIC-016 commits 影响 | P0 | 无 W1-2 shadow 覆盖测试 |
| 改动包在 if 块里丢配置 | authz 检查包在条件逻辑里可能被绕过 | P1 | realpath 必须无条执行 |
| Performer 误路由到 miao | scripts/authz/ 若 later 移入 worktree 范围, 保护失效 | P1 | git hook 强制 |
| 性能优化导致 cold path 退化 | ReBAC realpath 在 NFS 可能 >5ms | P1 | timeout 保护 |

---

## 4. 12 项 P0 修复项 (5 专家共识, 按优先级排序)

| # | 修复项 | 阻断 | 来源专家 | 估时 |
|---|---|---|---|---|
| 1 | **EPIC-017 跟踪 10 issue** (O 5 修 + 安全 5 issue, 必须 W4 hard 切换前完成) | 阻塞 W4 hard 切换 | DevOps | 1d (tracking) + 1-2d (fix) |
| 2 | **fail-closed 强制** (authz check 错误时 exit 1 deny, 不 silent allow) | 阻塞 v1 启动 | Backend/Security | 0.5d |
| 3 | **4 个 authz 脚本加 `set -euo pipefail`** | 阻塞 v1 启动 | Backend | 0.5d |
| 4 | **FIFO 写非阻塞** + 容量检查 + watchdog (防 session_start.sh 类卡死) | 阻塞 v1 启动 | Backend/Architect | 1d |
| 5 | **Hot path 改 Python/Node** (bash 达不到 10ms, 实际 20-50ms) | 性能不可接受 | Backend | 1-2d |
| 6 | **Hard→Soft rollback SOP runbook** (step-by-step, 含 session_start 状态恢复) | 阻塞 W4 hard flip | Architect/DevOps | 0.5d |
| 7 | **21 CLOSING Phase 0 SOP** (Week 0 预清理脚本 + 验证 + 迁移期间 >5 告警) | 阻塞 v1 | Product/DevOps | 0.5d |
| 8 | **测试时间 ≥30% 拆解** (18d → 12-14d 实际, 含集成 + E2E + shadow replay) | 质量风险 | DevOps | 5-6d (含在 12-14d 内) |
| 9 | **Shadow replay** (历史 audit log 在 shadow mode 验证决策, 防止硬切换后才发现 bypass) | 阻塞 hard flip | DevOps | 1d |
| 10 | **实时告警** (audit log 实时流 + 阈值告警, 替代 T+1 grep) | 可观测性 | DevOps | 0.5d |
| 11 | **ReBAC 推 v2** (RBAC-only 够用, file_scope 已在 ticket.json) | 范围收敛 | Product/Security | 0d (范围决策) |
| 12 | **F1 Hard Enforcement 升 P0** + v1 只做 readonly+auditor+delegation (6 role → 3 role) | 优先级 | Product | 0d (范围决策) |

**总估时**: 12-14 days (Product 缩小版) vs 原 18 days

---

## 5. EPIC-017 建议范围 (Product 缩小版)

### v1 必做 (12-14 days, 3 engineers)

```
F1 Hard Role Enforcement (升 P0)
  - pre-commit hook 调用 authz/check.sh
  - Soft → Hard mode 切换 with rollback SOP
  - 多层防御: pre-commit + session_start + heartbeat

F1 内置 readonly (Week 1)
  - read-only 角色, 0 冲突纯加
  - viewer 场景的 stakeholder 支持

F3 Delegation TTL
  - master 可委托 review authority / merge authority 给 conductor
  - TTL 自动 expire, 紧急 hotfix 场景

Auditor role (Week 2)
  - read-only + audit.export
  - EPIC-016 合规要求

5 个 P0 修复 (#1-#6 上面)
  - EPIC-017 跟踪 10 issue
  - fail-closed 强制
  - set -euo pipefail
  - FIFO 非阻塞 + watchdog
  - Hot path Python/Node
  - Hard→Soft rollback SOP

测试 + Shadow replay + 实时告警 (#8-#10)
```

### 推迟 v2

```
F2 super-admin + emergency-responder
F4 ReBAC scope (RBAC-only 够用, file_scope 已在 ticket.json)
F5 CLOSING GC → Week 0 预清理 (独立 SOP)
Multi-master failover
Runtime permissions.yml hot-reload
Permission delegation chain visualization
LDAP/SSO integration
Audit log compression + export
```

### 独立 EPIC-018 (1-2 days)

```
EPIC-018: O 卡 5 修 + 安全 review 5 issue
  - 必须在 EPIC-017 W4 hard 切换前完成
  - 阻塞 W4 的 P0
```

---

## 6. 决策点 (待 master 仲裁)

1. **批准 v1 缩小版范围** (Product 建议, 12-14 days, 3 role vs 6 role)?
2. **EPIC-017 范围确认** (必做 vs 推迟 v2 列表)?
3. **EPIC-018 单建** (O 5修 + 安全 5 issue, 优先级 P0 阻塞 W4)?
4. **5/5 专家 NO 评分的处理**:
   - (A) 先做 P0 修复再批准, 或
   - (B) 批准 v1 草案但带 P0 阻塞条件?
5. **Phase 0 (本周) 立刻执行哪些?**
   - 0.1 EPIC-017 tracking ticket 创建
   - 0.2 EPIC-018 修复 10 issue (1-2 days)
   - 0.3 21 CLOSING 预清理
   - 0.4 Hard→Soft rollback SOP 写
6. **下一步授权**: master 调度 5 subagent (按需并行/串行) + master 编排, 你看汇总

---

## 7. 关联文档

- `confluence/decisions/PERMISSION-MODEL.md` — 5 专家合成 (Conductor 写)
- `confluence/decisions/PERMISSION-PANEL-RAW-2026-06-07.md` — 5 专家原始输出
- `confluence/decisions/EPIC-016-POSTMORTEM-2026-06-07.md` — EPIC-016 复盘 (7 经验教训)

**Last updated**: 2026-06-07
**Status**: 5 专家评审完成, 综合报告待 master 仲裁
