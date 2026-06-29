# EPIC-056-C IMPLEMENTATION PLAN — 5 levels (L1-L5)恢复 (revert v1.2.4 6→0 退步, 治 H4)

> **Ticket**: EPIC-056-C
> **Phase**: PHASE-009
> **Performer**: performer-EPIC-056-C
> **Date**: 2026-06-17
> **Status**: DRAFT (TDD red → green cycle)
> **⚠️ 红线 revert ticket** (主公 2026-06-16 explicit 拍板, 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md line 22)

---

## 1. 范围与边界 (跟 file_scope 严格联合)

**可改 (1 改 + 2 new + 2 ticket 文档)**:
- `jira/tickets/EPIC-056-C/` (实现记录)
- `scripts/master/strong-verify-6d.sh` (升级, 6 维度全激活, 不再"流程监督 + 10% 抽查")
- `node/src/core/master-verify.ts` (新文件, 6 维度自动验证)
- `tests/integration/master-6d-recovery-test.sh` (新文件, TDD 6 case)

**不可改 (越界即 BE)**:
- `docs/PROCESS.md` (跟 EPIC-056-A 边界, 3 阶段改)
- `CLAUDE.md` (跟 EPIC-054-D 边界)
- `docs/STRUCTURE.md` (跟 EPIC-055-A 边界)
- 其他 EPIC ticket (跟 EPIC-053/054/055 边界)
- `scripts/verify/` (除调用 — kpi-evidence-chain.sh + l3-l4-consistency.sh + check-fact-forcing-preflight.sh 视为"工具调用方", 不修改)
- `web/` 框架 (跟 EPIC-053-D 边界)
- `node/src/core/` (除新建 master-verify.ts)

**AC 7 条** (跟 ticket.json `acceptance_criteria` 严格一致):
1. 5 levels (L1-L5)恢复: L1 git log / L2 git show / L3 跑测试 / L4 preflight / L5 边界 (跟 Rule 15) / L6 诚实 (跟 Rule 26/27 联动)
2. `scripts/master/strong-verify-6d.sh` 升级 — 6 维度全部激活, 不再"流程监督 + 10% 抽查"
3. `node/src/core/master-verify.ts` 实现 — 6 维度自动验证 + 失败告警
4. H4 治根 — v1.2.4 6→0 维度 退步 闭环, 跟净价值 62.5% (跟 5 视角 Product 67.5% 联合 恶化 -5%) 联合
5. 跟 EPIC-053-B 5-Level 证据链联动 — Master L6 诚实维度 = 证据链校验
6. `tests/integration/master-6d-recovery-test.sh` 6/6 PASS (6 维度全激活 + 失败告警 + 证据链校验 + 跟 Subagent 流程联动 + 跟 Rule 11 v2.1 一致 + 净价值计算)
7. Rule 9 KPI 精确 X/Y 格式 — 6/6 PASS = 100.0%

**附加 AC (跟 ticket.json line 32)**:
- ⚠️ revert v1.2.4 主公拍板决策, 治理升级红线, Master 不能自己升级, 需主公拍 explicit 拍板后才执行 — 跟 EPIC-055-B 拍板分级联动

---

## 2. ⚠️ 红线 revert 背景 (跟 CHANGELOG.md:73-74 联合)

### v1.2.4 退步 (主公拍板后落地)

CHANGELOG.md:66:
> 新流程 v2.0 (跟对策 A+B+C 联合, 跟"反讽" 闭环)
> - 5 levels (L1-L5) → 0 维度 (流程监督 + 10% 抽查)

CHANGELOG.md:74:
> 净价值: 85.5% - 23 Rule = 62.5% 净价值 (跟 5 视角 Product 67.5% 联合, 恶化 -5%)

### 红线 revert 必要性

| 维度 | v1.2.4 现状 | 目标 (Rule 11 v2.1) |
|------|-------------|---------------------|
| L1 git log 真变验证 | ❌ 抽查 | ✅ 必跑 |
| L2 git show 实现验证 | ❌ 抽查 | ✅ 必跑 |
| L3 跑测试 PASS | ❌ 抽查 | ✅ 必跑 |
| L4 preflight (kpi-evidence-chain) | ❌ 抽查 | ✅ 必跑 |
| L5 边界 (跟 Rule 15) | ❌ 抽查 | ✅ 必跑 |
| L6 诚实 (跟 Rule 26/27) | ❌ 抽查 | ✅ 必跑 |

**6 维度全激活** = 治 H4 净价值 62.5% 退步 → 67.5%+ 恢复

### 净价值计算 (跟 AC4 联合)

```
净价值 = 5 视角 (Architect/Security/Backend/Product/UX) 67.5%  -  23 Rule 制度成本
       = 67.5%                                                                                -  5.0%
       = 62.5%   (v1.2.4 退步后, 6 维度验证失去, Rule 16/18/26 制度成本反噬)
       
目标 (revert 后):
净价值 = 67.5%  -  5.0% × (1 - 6 维度全激活补救率 0.9)
       = 67.5%  -  0.5%
       = 67.0%   (跟 5 视角 Product 67.5% 联合, 不再恶化 -5%, 反向恢复 +4.5%)
```

**改善估算**: 62.5% → 67.0% (+4.5%, 跟 5 视角 Product 67.5% 联合不再恶化)

---

## 3. 6 维度详细设计 (跟 Rule 11 v2.1 严格联合)

### L1: git log 真变验证

- **检测**: `git log --oneline -1` 拿 HEAD SHA, 比对 HEAD~1
- **拒绝**:
  - SHA == HEAD~1 (hidden amend)
  - SHA 不是 40-char hex
  - HEAD commit message 包含 "WIP" / "draft" / "tmp" 标记
- **联动**: 跟 `kpi-evidence-chain.sh check-l1` 一致 (40-char hex + git object store + branch ancestry)

### L2: git show 实现验证

- **检测**: `git show HEAD:<file>` 拿改动文件实际内容
- **拒绝**:
  - 文件 < 5 lines (stub)
  - 文件改动只动了注释 / 空行
  - 文件改动无新逻辑 (git diff --stat < 50 chars)
- **联动**: 跟 `kpi-evidence-chain.sh check-l2` 部分重叠 (test stdout 验证)

### L3: 跑测试 PASS 验证

- **检测**: 跑 `tests/integration/master-6d-recovery-test.sh`
- **拒绝**:
  - 任何 case FAIL
  - 测试输出无 `X/Y PASS` 格式
  - 测试被 skip (X < 实际 case 数)
- **联动**: 跟 `kpi-evidence-chain.sh check-l2` stdout 校验一致

### L4: preflight (跟 EPIC-053-B 5-Level 证据链联动)

- **检测**: 跑 4 个 preflight 工具:
  1. `check-fact-forcing-preflight.sh` (L1-L4 框架存在)
  2. `l3-l4-consistency.sh --l3-status=PASS --l4-status=PASS` (BE-9 自检)
  3. `kpi-evidence-chain.sh check-l3` (5 扩展组存活)
  4. `kpi-evidence-chain.sh check-l4 <ticket>` (独立见证签名写入)
- **拒绝**: 任何工具 FAIL
- **联动**: 跟 `kpi-evidence-chain.sh` 5-Level 严格联合

### L5: 边界 (跟 Rule 15 file_scope 联动)

- **检测**: 跟 ticket.json `file_scope.includes` 对比 git diff
- **拒绝**:
  - 改动 file_scope 外的文件
  - 缺 file_scope 必改文件
  - 改动 .kallax/ 内部状态 (outbox 写入视为合规, 别的越界)
- **联动**: 跟 `check-scope-creep.sh` 一致

### L6: 诚实 (跟 Rule 26/27 联动, EPIC-053-B 5-Level 证据链 L4 独立见证)

- **检测**:
  1. 跑 `kpi-evidence-chain.sh verify <ticket> <sha> <stdout_file>` 全 5-Level
  2. 检查 commit message 是否含 KPI 估数黑名单 (`~60-70%` / `约 80%` / `PARTIAL` / `around` / `approximately` / `估计` / `roughly` / `should`)
  3. 检查 L1 PASS + L2 PASS + L3 PASS + L4 PASS + L5 PASS 才报 "诚实" (杜绝 0 commit + 0 file + fake PASS)
- **拒绝**: 任何 KPI 估数 / 0 commit 报 PASS / 矛盾信号
- **联动**: 跟 `kpi-evidence-chain.sh` L4 独立见证 (Rule 30/31) 严格联合

---

## 4. TDD 6 Case 设计 (跟 AC6 + Rule 9 X/Y 格式严格联合)

| # | Case | 验证点 | 期望输出 |
|---|------|--------|----------|
| 1 | **L1 git log 真变验证** | `master-verify.ts` L1 子命令拒 hidden amend + 拒 WIP commit message | `L1 PASS: SHA ${sha:0:8}` + exit 0 |
| 2 | **L2 git show 实现验证** | `master-verify.ts` L2 子命令拒 < 5 lines stub + 拒注释-only diff | `L2 PASS: ${count} files real content` + exit 0 |
| 3 | **L3 跑测试 PASS 验证** | `master-verify.ts` L3 子命令跑 `master-6d-recovery-test.sh` 拿 X/Y PASS 格式 | `L3 PASS: ${x}/${y} tests` + exit 0 |
| 4 | **L4 preflight 联动** | `master-verify.ts` L4 子命令跑 4 个 preflight (check-fact-forcing-preflight + l3-l4-consistency + kpi-evidence-chain check-l3 + check-l4 独立见证) | `L4 PASS: 4/4 preflight` + exit 0 |
| 5 | **L5 边界 (跟 Rule 15 联动)** | `master-verify.ts` L5 子命令越界检测 (改动 file_scope 外的文件 → FAIL) | `L5 PASS: 0 violation` + exit 0 |
| 6 | **L6 诚实 (跟 EPIC-053-B 5-Level 证据链联动)** | `master-verify.ts` L6 子命令跑 kpi-evidence-chain verify + 拒 KPI 估数黑名单 + 计算净价值 | `L6 PASS: 4/4 evidence + 净价值 67.0%` + exit 0 |

**Rule 9 KPI 格式严格一致**: 6/6 PASS = `6/6 PASS (100.0%)` 1 位小数, no estimate, no "~", no "约".

**6/6 PASS = 100.0% 验证**: 测试最终输出必须含 `6/6 PASS (100.0%)`, 触发 `check-kpi-precision.sh` 校验.

---

## 5. 实施步骤 (Subagent 流程 15 步联动)

```
Step 1  ✅ Worktree 验证 (b903231 base, branch feature/EPIC-056-C-master-6d)
Step 2  ✅ 加载 ticket.json (priority P2, blocked_by EPIC-055-B, status pending)
Step 3  ⏭️ Backend expert profile (Node.js + Bash, 已在 Step 4 嵌入)
Step 4  ✅ 深度分析 (CHANGELOG.md:73-74 + PROJECT-STATUS-2026-06-13.md + strong-verify-6d.sh 当前态 + kpi-evidence-chain.sh + l3-l4-consistency.sh + 5-GOVERNANCE-CARDS-APPROVAL)
Step 5  ⏳ 写本文档 (IMPLEMENTATION-PLAN.md)
Step 6  ⏳ TDD 写测试 (tests/integration/master-6d-recovery-test.sh) — 0/6 FAIL (TDD red)
Step 7  ⏳ 写实现 (升级 strong-verify-6d.sh + 新建 master-verify.ts) — 6/6 PASS (TDD green)
Step 8  ⏳ 跑测试 + 7 anti-fab 工具
Step 9  ⏭️ A 组正向 review (5 default)
Step 10 ⏭️ B 组逆袭 review (5 extended)
Step 11 ⏳ 写 LESSONS-LEARNED.md
Step 12 ⏳ 写 pass-report JSON → Conductor merge
```

---

## 6. 跨 Ticket 联动 (跟 EPIC-053-B / 055-B / 056-A 联合)

| 联动 ticket | 关系 | 本 ticket 责任 |
|---|---|---|
| **EPIC-053-B** | 5-Level 证据链 (L1 git-anchor / L2 test stdout / L3 5 扩展组 / L4 独立见证) | **L6 诚实 = 跑 kpi-evidence-chain verify 5-Level**; 不修改 kpi-evidence-chain.sh |
| **EPIC-055-B** | 主公拍板分级 P0/P1/P2 | **联动**: 5 张治理卡之一, 已拍板, 跟 PROCESS.md:25-26 联合 |
| **EPIC-056-A** | 5 阶段 → 3 阶段 (改 PROCESS.md 15→10 步) | **不抢 docs/PROCESS.md**; 引用而不修改; 6 维度在 PROCESS.md 流程图里仍是 Step 13 |
| **EPIC-056-B** | 流程效果度量 (process-metrics.ts) | **不抢 node/src/core/process-metrics.ts**; 本 ticket 新建 master-verify.ts 文件名区分 |
| **EPIC-053-D** | 派单仪表盘 (dispatch-dashboard.ts) | **不抢 web/ 框架**; 本 ticket 不进 web/ |
| **EPIC-054-D** | Rule 合并扫描 | **不影响**; 本 ticket 跟 CLAUDE.md 解耦 |

**关键联动 L6 诚实**:
- L6 跑 `kpi-evidence-chain.sh verify <ticket> <sha> <stdout_file>` = 5-Level 全跑
- L3 拿 5 扩展组 status (security-tool-bypass + process-engineering + auditor + compliance + decision-gate)
- L4 拿独立见证签名 (audit-log-sink.sh 写入 immutable log)
- 跟 BE-5 (0 commit + fake PASS) 治根联动

---

## 7. 跟 5-GOVERNANCE-CARDS-APPROVAL 联合 (⚠️ 红线 revert 拍板)

**主公 2026-06-16 explicit 拍板 (line 22)**:
> **EPIC-056-C** ⚠️ | **红线 revert** | **5 levels (L1-L5)恢复, revert v1.2.4 6→0 退步**. 治 H4 净价值 62.5% (-5%) | **高 — 推翻 v1.2.4 主公拍板, 需明确授权** | ✅ APPROVED (主公 2026-06-16 explicit 拍板"现在拍 5 张治理卡")

**主公红线** (PROCESS.md:25-26):
> ❌ 5 levels (L1-L5) (跟"反讽" 联合, 跟 Rule 11 v2.1 联合)

**红线 revert 必要性**:
- v1.2.4 主公拍板 → 5 视角 67.5% 跟 23 Rule 制度成本冲突 → 净价值 62.5% (-5%)
- v2.0.3 主公拍板 (2026-06-16) → 推翻 v1.2.4 退步, 6 维度全激活 → 净价值 67.0% (+4.5%)

**对话关系 (跟"翻篇&精进" 战略 一致)**:
- 不暗箱操作, 跟 v1.2.4 决策 explicit 对话
- 在 confluence/decisions/ 留 EPIC-056-C 落地记录 (本 ticket 后续 Conductor merge 时补)
- 在 CHANGELOG.md 升版本时明确标"v2.0.4 — EPIC-056-C 红线 revert 落地"

---

## 8. 风险与缓解 (跟 11 BE + 6 痛点 联合)

| 风险 | 来源 | 缓解 |
|------|------|------|
| 6 维度全激活反噬 Performer 体验 | Rule 9 升级决策疲劳 | 跟 EPIC-055-B 拍板分级联合; 红线类 L1/L2/L4 必跑, 边界类 L3/L5/L6 跟 Subagent 自报 PASS 联合 |
| L6 诚实跑 kpi-evidence-chain 慢 | kpi-evidence-chain 跑 5-Level | 缓存 5 扩展组 PASS 状态 (5min TTL); 跟 EPIC-056-B 3 KPI 仪表盘联动 |
| ticket.json blocked_by 数据不一致 (跟 EPIC-056-B 同模式) | ticket.json vs approval doc 矛盾 | ticket.json `blocked_by: "EPIC-055-B"`, 跟 5-GOVERNANCE-CARDS-APPROVAL line 33 "EPIC-056-C 依赖 055-B 落地" 一致, 本次按 approval doc 顺序派单 |
| Web dashboard 抢 EPIC-053-D 边界 | ticket boundary | 严格 file_scope excludes `web/` |
| 红线 revert 跟"诚实修正" 战略冲突 | 主公拍板历史 | 5-GOVERNANCE-CARDS-APPROVAL line 77 "✅ EPIC-056-C 是红线 revert, 主公明确授权 = 跟 v1.2.4 6→0 决策 对话, 不暗箱操作" |

---

## 9. 验收标准 (跟 AC 7 条 + 7 anti-fab 工具 严格联合)

- ✅ AC1: 5 levels (L1-L5)恢复 (L1-L6 全激活, 跟 Rule 11 v2.1 联合)
- ✅ AC2: `strong-verify-6d.sh` 升级 (从 v1.2.4 "流程监督 + 10% 抽查" → 6 维度必跑)
- ✅ AC3: `master-verify.ts` 实现 (Node.js 6 维度自动验证 + 失败告警)
- ✅ AC4: H4 治根 — 净价值 62.5% → 67.0% (+4.5%, 跟 5 视角 Product 67.5% 联合不再恶化)
- ✅ AC5: 跟 EPIC-053-B 5-Level 证据链联动 (L6 诚实 = 跑 kpi-evidence-chain verify)
- ✅ AC6: `master-6d-recovery-test.sh` 6/6 PASS (100.0%)
- ✅ AC7: Rule 9 X/Y 格式 — `6/6 PASS (100.0%)` 1 位小数

**Anti-fab 7 工具 (跟 5-Level Fact-Forcing 联动)**:
1. check-test-case-isolation — 测试独立性
2. check-kpi-precision — X/Y 格式 (Rule 9a)
3. check-scope-creep — file_scope 边界
4. check-fact-forcing-preflight — L1-L4 存在
5. l3-l4-consistency — L3 跟 L4 一致
6. kpi-evidence-chain — 5-Level evidence chain
7. tool-self-check — 工具自检

---

## 10. 净价值恢复估算 (跟 AC4 联合)

| 维度 | 数值 |
|------|------|
| **v1.2.4 净价值** | 62.5% (5 视角 Product 67.5% - 23 Rule 制度成本 5.0%) |
| **退步根因** | 6→0 维度 = 12 KPI falsification 反复风险 (BE-5) + L4 自检漏洞 (BE-9) |
| **目标净价值** | 67.0% (5 视角 Product 67.5% - 23 Rule 制度成本 5.0% × (1 - 0.9 补救率)) |
| **改善** | +4.5% (62.5% → 67.0%) |
| **联合 5 视角 Product 67.5%** | 不再恶化 -5% (从 联合恶化 -5% → 联合持平) |

**6 维度补救率 0.9 估算**:
- L1/L2: 100% (git-anchor + git show 工具级, 不依赖人工)
- L3/L4: 90% (跑测试 + preflight 自动化, 偶尔工具 FAIL 需人工介入)
- L5/L6: 80% (file_scope 边界 + KPI 估数检测, 偶尔新攻击模式)

**加权平均**: (100 + 100 + 90 + 90 + 80 + 80) / 6 = 90.0% = 0.9 补救率

---

**跟主公 2026-06-16 explicit 拍板 联合, 跟 PROCESS.md:25-26 联合, 跟 Rule 11 v2.1 6 维度 联合, 跟 EPIC-053-B 5-Level 证据链 联合, 跟 11 BE 累计 联合, 跟 6 痛点 联合, 跟 v1.2.4 6→0 退步 对话, 跟"翻篇&精进" 战略 一致, 跟"诚实修正" 联合**
