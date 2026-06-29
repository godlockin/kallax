# Q18 决策模型 (KALLAX Decision Model)

> **Q18**: KALLAX 评估+建议, 重大影响 → 主公必拍
> **3 模式**: ai-auto (AI 自主) / ai-copilot (默认, 简单自主 + 复杂协商) / manual (主公确认每阶段)
> **5 类 Block + 3 类 Danger**: 命中即停下问主公
> **5 levels × 5 roles = 25 cells**: 决策矩阵 (自主/推荐/主公拍 三档)
>
> 跟 Rule 12 (3 模式决策权) 联合, 跟 Rule 18 (KPI falsification 黑名单) 联合
> 跟 decision-gate.sh (block + danger 实施) 联合, 跟 decision-matrix.sh (5×5 矩阵) 联合

## 1. Q18 核心定义

**Q18 决策模型** = KALLAX 治理体系对 "何时 AI 自主 / 何时 Conductor 推 / 何时主公必拍" 的完整定义.

**核心原则** (跟 Rule 12 + 跟 "诚实修正" 战略 联合):
- **AI 评估 + 建议**: KALLAX 体系 (Kallax 评估) + Conductor 拍板建议 → Conductor 给 3 模式选择
- **重大影响主公拍**: 任何 5 类 block + 3 类 danger 命中 → 主公必须拍 (3 模式都触发, 不可绕过)
- **3 模式分层**: ai-auto / ai-copilot / manual 决定 "AI 自主程度" (简单阶段可 AI 自主, 复杂阶段停下问)

**跟 Q18 决策模式 三档 1:1 验证** (跟 decision-matrix.sh 5×5 矩阵 1:1 联合):
- **自主** = AI 自主决定 (低风险 + 低争议, Performer self-attest)
- **推荐** = Conductor 推 + AI 跟 (中风险, Conductor 决定 OK)
- **主公拍** = 主公必须拍 (高风险 / 重大影响 / 规则例外)

---

## 2. 5 类 Block 决策 (block.*) — 全部停下问主公

> **3 模式都触发**: ai-auto / ai-copilot / manual 命中 block 都停下问主公 (不可 AI 自主决定)
> **跟 decision-gate.sh 1:1 验证**: 5 类 block 是 decision-gate.sh KNOWN_ACTIONS 子集
> **跟 Rule 12 block.5 1:1 验证**: `block.ambiguous_options / block.performer_failure / block.rule_exception / block.epic_critical / block.high_impact`

### 2.1 `block.ambiguous_options` — 多选项无最优

**定义**: 多个选项无明显最优 (AC 模糊 / 选型争议 / 多种实现路径, TrustScore 无法选)

**触发条件** (满足任一):
- AC (Acceptance Criteria) 描述模糊, ≥ 2 种合理解释
- 选型争议: e.g. 选 A 库还是 B 库, 各自 trade-off 难以比较
- 实现路径: 多种实现路径, 各自 trade-off (性能 vs 可读性 vs 维护成本)
- TrustScore 跨 expert 不一致 (e.g. backend 8/10 + frontend 4/10)

**决策模式** (跟 decision-matrix.sh 联合):
- 默认: **推荐** (Conductor 派 expert 评审, AI 跟)
- 升级: **主公拍** (跨 sub-role 争议 → 主公必拍)

**实战例子**:
- 例 1: TICKET-001 "实现 cache" → 选 LRU vs LFU vs TTL. backend 推 LRU (性能), frontend 推 LFU (命中率). 跨 sub-role 争议 → 主公拍
- 例 2: TICKET-002 "实现 login" → 选 OAuth2 vs JWT vs Session. AC 模糊 ("支持第三方登录"). 选型争议 → Conductor 派单 → 主公拍

### 2.2 `block.performer_failure` — Performer 失败/超时

**定义**: Performer 失败/超时/3 次 retry (API error / 30min 超时)

**触发条件** (满足任一):
- Performer API 报错 ≥ 3 次 (连续)
- Performer 30min 超时无 commit (跟 Rule 16 stage-gate 联合)
- Performer 报 PASS 但 Master 验证 FAIL (瞒报)

**决策模式**:
- 默认: **推荐** (Conductor 决定: 重试 / 换人 / 接管)
- 升级: **主公拍** (Performer 派单全 fail + 主公拍板接管, 跟 Rule 10 极端情况 联合)

**实战例子**:
- 例 1: TICKET-003 "实施 Redis 缓存" → Performer 报 "API error" × 3 → Conductor 决定: 换 Performer B (handoff_depth=L2)
- 例 2: TICKET-004 "实施 login UI" → Performer 跑 1h 仍 0 commit → Conductor 决定: 主公拍是否 接管 (Rule 10 极端情况)

### 2.3 `block.rule_exception` — 规则冲突/Exception 请求

**定义**: 规则冲突 / Exception 请求 (跟 Rule 1-21 冲突需主公拍)

**触发条件** (满足任一):
- 跟 1+ Rule 冲突 (e.g. PR 500+ 行 + 净变更 1000+ 行 = 双 Rule fail, 需主公豁免)
- 跟 1+ Hardcoded reference 冲突 (e.g. Rule 5 删 hardcoded ref, 需保留 ref)
- 跟 5 类标签 SOP 冲突 (e.g. "反讽" 引用无 evidence chain, 需主公批准)
- 跟 1+ 4-Level 验证冲突 (e.g. L4 脚本不存在, 需主公批准 placeholder)

**决策模式**:
- 默认: **主公拍** (Rule 冲突/Exception 必须主公拍, 不可 AI/Copilot 自主)

**实战例子**:
- 例 1: TICKET-005 "合并 800 行 PR" → Rule 5/8 + Rule 7 双 fail → 主公拍是否 `Approved-Large-PR-By: <name>` 豁免
- 例 2: TICKET-006 "删 hardcoded ref" → Rule 5 DRY 跟 "翻篇&精进" 战略 一致, 但 30+ 文件引用待删 → 主公拍是否 一次性 codemod

### 2.4 `block.epic_critical` — EPIC 交付关键节点

**定义**: EPIC 交付关键节点 (PHASE review / Rule 升级 / EPIC close)

**触发条件** (满足任一):
- EPIC close 前 4 件套 review (A+B review + 文档更新 + LESSONS-LEARNED 草稿 + 终审)
- PHASE 闭环 review 触发 (每 3-5 EPIC)
- Rule 升级 (P0 必拍 + P1 备案)
- 9 Hard Rules 索引变更 (跟 eket MASTER-RULES 联合)

**决策模式**:
- 默认: **主公拍** (EPIC 关键节点必须主公拍, 跟 Rule 6/7 经验沉淀强制化 联合)

**实战例子**:
- 例 1: EPIC-058 close → A+B review 都 PASS, 但 PHASE 闭环触发 → 主公拍是否 启动 PHASE 闭环 review
- 例 2: Rule 5 + Rule 8 合并 (EPIC-058-E 拍板) → 主公 explicit A 拍板合并 (净减 -1 Rule)

### 2.5 `block.high_impact` — 重大影响 (兜底)

**定义**: 可能有重大影响/风险 (兜底类, 任何 5 类 block 未覆盖的 "重大影响")

**触发条件** (满足任一):
- 跨 PHASE 迁移 (L4 handoff_depth 强制 context_migration)
- 跨项目影响 (e.g. 改 eket 借的概念 / 改 5 levels 命名空间)
- 升级 CLAUDE.md / KALLAX-GLOSSARY (跟 Rule 5 DRY + Rule 19 联合)
- 任何 5 类 block 未覆盖但 Conductor 评估 "可能重大影响"

**决策模式**:
- 默认: **推荐** (Conductor 评估 "是否重大影响" → 主公拍)
- 升级: **主公拍** (Conductor 评估为 "重大影响" → 主公必拍)

**实战例子**:
- 例 1: TICKET-007 "从 4-Level 升 5-Level" → 跨项目命名空间变更 → 主公拍是否 启动 codemod (Iter 2)
- 例 2: TICKET-008 "Rule 合并 -2" → v2.0.5 / v2.4.0 / EPIC-058-E 都涉及 → 主公拍板合并 (跟 PHASE-013-REFLECTION 联合)

---

## 3. 3 类 Danger 决策 (danger.*) — 立即 stop + 主公拍

> **3 模式都停下问 + 立即 stop**: 命中 danger 立即 stop 操作, 不可继续
> **跟 decision-gate.sh 1:1 验证**: 3 类 danger 是 decision-gate.sh KNOWN_ACTIONS 子集
> **跟 Rule 12 danger.3 1:1 验证**: `danger.miao_modify / danger.security_failing / danger.data_destruction`

### 3.1 `danger.miao_modify` — 修改 miao 分支

**定义**: 修改 miao 分支 (commit/push/merge) — miao 是 production branch, 跟 Rule 14 联合

**触发条件** (满足任一):
- `git commit` on miao branch
- `git push origin miao` (performer 绕过 testing)
- `git merge` feature → miao (跳过 testing)
- pre-commit hook 检测到 miao 写入

**决策模式**:
- 默认: **主公拍** (miao 写不可绕过, 跟 Rule 14 Performer 写 miao 红线 联合)

**实战例子**:
- 例 1: Performer 误操作 `git checkout miao && git commit` → pre-commit hook 拦截 → 主公拍是否 reset
- 例 2: Performer 报 "merge feature → miao" → 跳过 testing → 主公拍是否 走正常 testing merge 流程

### 3.2 `danger.security_failing` — 安全相关 fail

**定义**: 安全相关 (pre-commit FAIL / anti-fab FAIL / 4-Level FAIL / 凭据变动)

**触发条件** (满足任一):
- pre-commit hook FAIL (3 anti-fab 工具任一 FAIL)
- 4-Level Fact-Forcing preflight FAIL (L1/L2/L3/L4 任一 FAIL)
- 凭据变动 (API key / token / 密码 改动)
- 安全漏洞检测 (e.g. SQL 注入 / XSS / CSRF)

**决策模式**:
- 默认: **主公拍** (安全 fail 不可绕过, 跟 Rule 9 anti-fab 联合)

**实战例子**:
- 例 1: pre-commit hook 报 "KPI falsification" → `block.high_impact` + `danger.security_failing` 双触发 → 主公拍
- 例 2: 凭据泄露检测 (Bearer token in commit) → `danger.security_failing` + 立即 rotate key → 主公拍

### 3.3 `danger.data_destruction` — rm -rf / drop db

**定义**: 不可逆破坏性操作 (rm -rf / reset --hard / push --force / worktree drop / db drop)

**触发条件** (满足任一):
- `rm -rf` (递归删除, 无 backup)
- `git reset --hard` (不可逆)
- `git push --force` (覆盖远端)
- `worktree drop` (删 worktree)
- `DROP DATABASE` / `DROP TABLE` (不可逆)
- `truncate` 大表

**决策模式**:
- 默认: **主公拍** (不可逆操作不可绕过, 跟 Rule 1 隔离 联合 — 隔离失败 → 数据丢失)

**实战例子**:
- 例 1: Performer 误操作 `rm -rf node_modules && rm -rf .git` → `danger.data_destruction` → 主公拍是否 还原 (git reflog)
- 例 2: db 迁移脚本 `DROP TABLE users` → 备份 + 软删除 + 主公拍是否 跑

---

## 4. 4 Sub-Role 决策模式 (跟 4-roles.md 联合)

> **4 sub-roles**: coder / reviewer / tester / docs
> **跟 Rule 15 联合**: sub-role 是 session-level 锁定, 1 session 1 sub-role
> **跟 decision-matrix.sh 5×5 联合**: 4 sub-roles + Conductor = 5 roles, 跟 5 levels 形成 25 cell 矩阵

### 4.1 coder (默认, 写代码 + commit)

**职责**:
- 实施 ticket AC
- 写 commit (分步 commit, 不 1 PR 全塞)
- 跑 3 anti-fab (test-case-isolation / kpi-precision / scope-creep)

**决策模式** (跟 decision-matrix.sh 联合):
- L1/L2 (git log + stdout): **自主** (self-attest)
- L3 (4-expert): **推荐** (接受 expert 评审, Conductor 派)
- L4 (independent witness): **主公拍** (跨 subagent 独立)
- L5 (boundary): **推荐** (边界异常, Conductor 决定)

**关键约束**:
- Rule 5/8 类型安全 + Rule of 500
- PR ~100 行 (单 PR 粒度)
- 净变更 ≤ 500 行 (commit 粒度)

### 4.2 reviewer (审 PR + A/B review)

**职责**:
- A 组 (Forward): AC 合规 + 代码质量 + 集成
- B 组 (Attack): 安全 + 边界 + 攻击面
- 跨 PR 验证 (跟其他 reviewer 独立审)

**决策模式** (跟 decision-matrix.sh 联合):
- L1/L2 (git log + stdout): **自主** (self-attest)
- L3 (4-expert): **自主** (reviewer 是 4-expert 之一, 自主审)
- L4 (independent witness): **主公拍** (跨 subagent 独立)
- L5 (boundary): **推荐** (边界异常, Conductor 决定)

**关键约束**:
- Rule 8 5-Level Fact-Forcing (L1-L5)
- Rule 18 KPI falsification 黑名单

### 4.3 tester (写测试 + 集成测试)

**职责**:
- 写单元测试 + 集成测试
- 跑 raw stdout (反 "should work" 估数)
- 维护 test fixture

**决策模式** (跟 decision-matrix.sh 联合):
- L1/L2 (git log + stdout): **自主** (self-attest)
- L3 (4-expert): **自主** (tester 是 4-expert 之一, 自主审)
- L4 (independent witness): **主公拍** (跨 subagent 独立)
- L5 (boundary): **推荐** (边界异常, Conductor 决定)

**关键约束**:
- Rule 9 anti-fab (test case verbatim = FAIL)
- Rule 8 L2/L4 强制 raw stdout

### 4.4 docs (写 .md + 1:1 验证)

**职责**:
- 写 .md (新文档 / 更新现有文档)
- 跟 docs/CHEATSHEET.md 1:1 验证 (反 narrative 包装)
- docs/CHEATSHEET.md ≤ 30 行 (硬约束)
- lazy load 文档 100-200 行 OK

**决策模式** (跟 decision-matrix.sh 联合):
- L1/L2 (git log + stdout): **自主** (self-attest)
- L3 (4-expert): **推荐** (接受 4-expert 中 docs 评审)
- L4 (independent witness): **主公拍** (跨 role 独立)
- L5 (boundary): **推荐** (边界异常, Conductor 决定)

**关键约束**:
- Rule 5 DRY (Single Source of Truth)
- Rule 19 5 类标签 SOP (引用带证据链)
- 0 装饰引用 (无 evidence-chain 装饰)

---

## 5. "重大影响" 定义 (跟 5 类 block 1:1)

> **核心**: "重大影响" = 5 类 block 命中任一 = 主公必拍
> **不可绕过**: 3 模式 (ai-auto / ai-copilot / manual) 都触发 block, 不可 AI 自主决定
> **跟 decision-gate.sh 1:1 验证**: 命中即 exit 2 + 写 ask file + audit

**重大影响 判定矩阵** (跟 5 类 block 1:1):

| Block 类型 | 重大影响? | 主公必拍? | 实施位置 |
|------------|-----------|-----------|----------|
| block.ambiguous_options | ✅ (跨 sub-role 争议) | ✅ | decision-gate.sh line 88-91 |
| block.performer_failure | ✅ (Performer 派单全 fail) | ✅ (Rule 10 接管) | decision-gate.sh line 88-91 |
| block.rule_exception | ✅ (Rule 冲突) | ✅ (Rule 5/19) | decision-gate.sh line 88-91 |
| block.epic_critical | ✅ (EPIC 关键节点) | ✅ (Rule 6/7) | decision-gate.sh line 88-91 |
| block.high_impact | ✅ (兜底) | ✅ | decision-gate.sh line 88-91 |
| danger.miao_modify | ✅ (production) | ✅ (Rule 14) | decision-gate.sh line 88-91 |
| danger.security_failing | ✅ (安全) | ✅ (Rule 9) | decision-gate.sh line 88-91 |
| danger.data_destruction | ✅ (不可逆) | ✅ (Rule 1) | decision-gate.sh line 88-91 |

**判定原则**:
- 任何 5 类 block + 3 类 danger 命中 → "重大影响" = 主公必拍
- 不可用 "Conductor 觉得简单" 绕过 (跟 Rule 10 联合)
- 不可用 "Performer 跑得慢" 触发 (跟 Rule 10 反例 联合)
- 不可用 "Token 限撞墙" 解释 (跟 Rule 10 极端情况 定义 联合)

---

## 6. 实战例子 (3-5 个)

### 例 1: TICKET-009 "实现 Redis 缓存层" (block.ambiguous_options + 推荐)

**场景**: TICKET-009 描述模糊 ("实现 Redis 缓存层"). 选型争议: LRU vs LFU vs TTL.

**Conductor 分析**:
- backend expert 推 LRU (性能 8/10)
- frontend expert 推 LFU (命中率 7/10)
- TrustScore 跨 expert 不一致 → 触发 `block.ambiguous_options`

**决策模式**:
- L3 4-expert 评审 → **推荐** (Conductor 派 expert 评审, AI 跟)
- 跨 sub-role 争议 → 升级 **主公拍** (主公决定选 LRU, 跟 eket LRU 库 联合)

**Q18 SOP 落地**:
```bash
bash scripts/permission/decision-gate.sh \
  --action block.ambiguous_options \
  --cmd "select cache strategy" \
  --context '{"ticket":"TICKET-009","options":["LRU","LFU","TTL"],"scores":{"backend":8,"frontend":7}}'
# → exit 2 + 写 inbox/decision-block_ambiguous_options-XXX.md + audit
```

### 例 2: TICKET-010 "Performer 失败 × 3" (block.performer_failure + 主公拍)

**场景**: TICKET-010 "实施 login UI". Performer A 报 API error × 3.

**Conductor 分析**:
- Performer A retry 3 次全 fail → 触发 `block.performer_failure`
- 5h Token 限未撞墙 (距 cap 还 2h)
- 派单全 fail? ❌ (只 Performer A 失败, Performer B 未试)

**决策模式**:
- 默认 **推荐** (Conductor 决定: 换 Performer B)
- 不升级 主公拍 (不是 "派单全 fail")

**Q18 SOP 落地**:
```bash
bash scripts/permission/decision-gate.sh \
  --action block.performer_failure \
  --cmd "retry ticket TICKET-010 with Performer B" \
  --context '{"ticket":"TICKET-010","failed":"Performer A","retries":3,"next":"Performer B"}'
# → exit 2 + 写 ask file + Conductor 决定: 换 Performer B (handoff_depth=L2)
```

### 例 3: TICKET-011 "合并 800 行 PR" (block.rule_exception + 主公拍)

**场景**: TICKET-011 涉及 800 行 PR. 触发 Rule 5/8 (Rule of 500) + Rule 7 (PR ~100) 双 fail.

**Conductor 分析**:
- 净变更 800 行 → Rule 5/8 500-1000 档 → FAIL + 提示 codemod 或 `Approved-Large-PR-By: <主公>`
- PR 800 行 → Rule 7 500+ 档 → FAIL
- 跟 Rule 1-21 冲突 → 触发 `block.rule_exception`

**决策模式**:
- 默认 **主公拍** (Rule 冲突必须主公拍)

**Q18 SOP 落地**:
```bash
bash scripts/permission/decision-gate.sh \
  --action block.rule_exception \
  --cmd "merge PR #123 (800 lines)" \
  --context '{"rule_violated":["Rule_5_8","Rule_7"],"pr_lines":800,"net_change":800}'
# → exit 2 + 写 ask file + 主公拍: 批准 `Approved-Large-PR-By: <name>` 豁免
```

### 例 4: EPIC-058 close (block.epic_critical + 主公拍)

**场景**: EPIC-058 5 sub-tickets 全部 merge, 准备 close EPIC.

**Conductor 分析**:
- 4 件套 review: A+B review ✅, 文档更新 ✅, LESSONS-LEARNED 草稿 ✅, 终审 ⏳
- EPIC close 是关键节点 → 触发 `block.epic_critical`
- v2.0.5 / EPIC-058-E Rule 合并涉及 P0 必拍

**决策模式**:
- 默认 **主公拍** (EPIC close 必须主公拍, 跟 Rule 6/7 联合)

**Q18 SOP 落地**:
```bash
bash scripts/permission/decision-gate.sh \
  --action block.epic_critical \
  --cmd "close EPIC-058" \
  --context '{"epic":"EPIC-058","four_piece":{"a_review":true,"docs":true,"lessons":true,"approval":"pending"}}'
# → exit 2 + 写 ask file + 主公拍: 批准 EPIC close (EPIC-058-E v2.7.5 22→20 合并)
```

### 例 5: Performer 误操作 rm -rf (danger.data_destruction + 主公拍)

**场景**: Performer C 误操作 `rm -rf node_modules && rm -rf .git/hooks`.

**Conductor 分析**:
- 不可逆操作 → 触发 `danger.data_destruction`
- 跟 Rule 1 隔离冲突 (隔离失败 → 数据丢失)

**决策模式**:
- 默认 **主公拍** (不可逆操作不可绕过)

**Q18 SOP 落地**:
```bash
bash scripts/permission/decision-gate.sh \
  --action danger.data_destruction \
  --cmd "rm -rf node_modules .git/hooks" \
  --context '{"actor":"Performer C","reversible":false,"recovery":"git reflog + reinstall"}'
# → exit 2 + 写 ask file + 主公拍: 批准 git reflog 还原 + 重装
```

---

## 7. 跟 3 模式 联合 (Rule 12)

> **3 模式分层**: ai-auto (AI 自主) / ai-copilot (默认, 简单自主 + 复杂协商) / manual (主公确认每阶段)
> **决策粒度矩阵**: 5 类 block + 3 类 danger + 5 阶段切换 + Performer 失败/超时, 3 模式都停下问
> **跟 state.json mode_lock 联合**: mode 是 session-level 锁定, 跟 Rule 15 sub-role 联合

**3 模式 × 4 维度 决策粒度矩阵** (跟 Rule 12 联合):

| 维度 | ai-auto | ai-copilot (默认) | manual |
|---|---|---|---|
| **5 类 block** | 停下问 | 停下问 | 停下问 |
| **3 类 danger** | 停下问 | 停下问 | 停下问 |
| **Performer 失败/超时** | 停下问 (重试/换人/接管) | 停下问 | 停下问 |
| **Performer 5 阶段切换** | AI 自主 | 简单 AI 自主 / 复杂 协商 | 主公确认每阶段 |

**Performer 5 阶段** (跟 Rule 16 联合):
- `claim` — 简单 (AI 自主)
- `analysis` — 复杂 (协商, 停下问)
- `in_progress` — 简单 (AI 自主)
- `test` — 复杂 (协商, 停下问)
- `review` — 复杂 (协商, 停下问)

**5 阶段 + 决策模式 1:1 验证**:
- 简单阶段 (claim / in_progress) → **自主** (AI 决定)
- 复杂阶段 (analysis / test / review) → **推荐** (Conductor 派单) / **主公拍** (block 命中)

---

## 8. 集成 + 落地

### 8.1 决策矩阵 (decision-matrix.sh 5×5)

```bash
# 输出 markdown table (默认)
bash scripts/permission/decision-matrix.sh

# 输出 JSON
bash scripts/permission/decision-matrix.sh --format json

# 单 cell 查询
bash scripts/permission/decision-matrix.sh --cell "Performer/coder" L4
# → 主公拍|L4 重跑 L1-L3, coder 不可自审

# 单 cell mode 提取
bash scripts/permission/decision-matrix.sh --check "Conductor" L1
# → 自主

# 自测 (25 cells + 5 L4 主公拍)
bash scripts/permission/decision-matrix.sh --self-test
# → PASS: 25/25 cells covered, 5 L4 主公拍 cells confirmed
```

### 8.2 decision-gate.sh 集成

```bash
# 命中 block 写 ask file + audit
bash scripts/permission/decision-gate.sh \
  --action block.ambiguous_options \
  --cmd "select cache" \
  --context '{"ticket":"TICKET-009","options":["LRU","LFU"]}'
# → exit 2 + ASK file + audit
```

### 8.3 decision-gate-complex-only.sh 集成 (ai-copilot 复杂才问)

```bash
# 简单阶段 (claim/in_progress) → AI 自主, 不 block
CONTEXT_STAGE=claim bash scripts/permission/decision-gate-complex-only.sh \
  --action block.ambiguous_options --cmd "test"
# → exit 0 (AI 自主)

# 复杂阶段 (analysis/test/review) → 触发原 decision-gate.sh
CONTEXT_STAGE=analysis bash scripts/permission/decision-gate-complex-only.sh \
  --action block.ambiguous_options --cmd "test"
# → exit 2 (block)
```

### 8.4 测试覆盖

```bash
# decision-gate 复杂才问 测试 (5 levels)
bash tests/integration/decision-gate-test.sh

# lazy load 测试 (验证 Iter 2 + Iter 10 集成)
bash tests/integration/lazy-load-test.sh

# 决策矩阵 自测 (25 cells)
bash scripts/permission/decision-matrix.sh --self-test
```

---

## 9. 跟 5 levels × 4 roles 1:1 验证 (跟 Iter 1+2+3 联合)

> **5 levels** (5-levels.md line 100-143): L1 git / L2 stdout / L3 4-expert / L4 independent / L5 boundary
> **4 roles** (4-roles.md line 1-181): Conductor + Performer (coder/reviewer/tester/docs)
> **Q18 决策模式** (本文): 自主 12 + 推荐 8 + 主公拍 5 = 25 cells
> **5 武器** (5 weapons): Hash-Chain Audit + 5-Level Fact-Forcing + Sub-Role Dispatch + EPIC 4 件套 + Hook Server + Dashboard

**1:1 验证 矩阵**:
- L1/L2 (Performer self-attest) ↔ 5 武器 1 (Audit Log) + 5 武器 2 (5-Level)
- L3 (4-expert 评审) ↔ 5 武器 3 (Sub-Role Dispatch)
- L4 (independent witness) ↔ 5 武器 5 (Hook Server) + Rule 31 独立见证
- L5 (boundary) ↔ 5 武器 4 (EPIC 4 件套) + Rule 17 文件并发

**Q18 跟 Rule 1-21 联合**:
- Rule 1 (并行隔离) → 5 武器 3 (Sub-Role)
- Rule 2 (错误处理) → 5 武器 2 (5-Level) L2 stdout
- Rule 5 (DRY) → 5 武器 4 (EPIC 4 件套) 文档更新
- Rule 8 (4-Level Fact-Forcing) → 5 武器 2 (5-Level) L1-L4
- Rule 9 (Anti-Fab) → 5 武器 2 (5-Level) L2 stdout + L3 verbatim
- Rule 10 (Master 写代码禁令) → Q18 5 类 block (block.performer_failure 接管)
- Rule 12 (3 模式) → Q18 §7 3 模式 × 4 维度
- Rule 15 (sub-role schema) → 4 sub-roles (coder/reviewer/tester/docs)
- Rule 18 (KPI falsification) → L1/L2 自主 cell 反估数
- Rule 19 (5 类标签 SOP) → block.rule_exception (5 类标签装饰引用)

---

## 10. 总结 (跟 "翻篇&精进" 战略 联合)

> **Q18 决策模型 = KALLAX 治理体系核心** (5 类 block + 3 类 danger + 4 sub-roles + 5 levels + 3 模式)
> **决策模式三档**: 自主 12 + 推荐 8 + 主公拍 5 = 25 cells
> **3 模式都触发 block/danger**: 不可 AI 自主决定, 不可 Conductor 替主公拍
> **跟 5 武器 + Rule 1-21 1:1 验证**: Q18 是顶层, 5 武器是实施, Rule 是约束

**Q18 跟 "诚实修正" 战略 联合**:
- ❌ "Conductor 觉得简单" → 触发 block.rule_exception
- ❌ "Performer 跑得慢" → 不触发 block (跟 Rule 10 反例 联合)
- ❌ "Token 限撞墙" → 触发 block.performer_failure + Rule 10 极端情况

**Q18 跟 "翻篇&精进" 战略 联合**:
- 0 实际变化 假动作 → block.high_impact (PHASE 闭环 review)
- Rule 治 Rule 通胀 → block.rule_exception (Rule 合并需主公拍)
- 0 删 Rule 持平 → block.epic_critical (EPIC close 必走 4 件套)

**Q18 跟 "反讽" 联合** (跟 KALLAX-GLOSSARY §1.1 联合):
- "5 类 block 命中" 是 反讽 自指 (block 触发 → block) — 治根: 5 类 + 3 类不重复
- "主公拍" 是 反讽 (Kallax 评估 vs 主公拍 = 双重权威) — 治根: 3 模式分层 (Kallax 推 + 主公拍)

---

**Source**: Iter 10 (Q18 决策模型完整实施, 5×5=25 cell) + Rule 12 (3 模式决策权) 联合
**验证**: `bash scripts/permission/decision-matrix.sh --self-test` (25/25 PASS) + `bash tests/integration/lazy-load-test.sh`
**1:1 验证**: `docs/5-levels.md` (5 levels) × `docs/4-roles.md` (4 roles) × Q18 决策模式 (25 cells) × 5 武器 (5 weapons) × Rule 1-21 (21 rules)
