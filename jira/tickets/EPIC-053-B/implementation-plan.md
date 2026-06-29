# EPIC-053-B Implementation Plan

> KPI falsification 系统级治根 — 5-Level 证据链 (git-anchor + test stdout + 5 扩展组 pass + 独立见证签名)
> P0 紧急 | 12h | branch: feature/EPIC-053-B-kpi-evidence-chain
> Performer: performer-EPIC-053-B | base SHA: 48e76f1 | blocked_by: EPIC-053-A (done)

---

## 1. 目标 (跟 AC 1:1 对齐)

实现 5-Level 证据链强制约束 — Performer 报 PASS 必须含全部 4 层证据, 缺 1 算 FAIL. 12 KPI falsification 反复 (EPIC-024/028/031/036/037/039-B) 系统级治根.

| AC | 描述 | 验证方法 |
|----|------|----------|
| AC1 | `kpi-evidence-chain.sh` 实现 — L1 git-anchor + L2 test stdout + L3 5 扩展组 + L4 独立见证签名 | 跑 `tests/integration/kpi-evidence-chain-test.sh` |
| AC2 | 6 case 全 PASS (5-Level 完整 + 缺 1 Level FAIL + 假 git-anchor FAIL + 假 test stdout FAIL + 5 扩展组不全 FAIL + 缺独立见证签名 FAIL) | 跑 `tests/integration/kpi-evidence-chain-test.sh` |
| AC3 | `node/src/core/output-verifier.ts` 升级 — Performer 报 PASS 必须含 5-Level 证据, 缺 1 算 FAIL | TypeScript 编译 + 测试 |
| AC4 | 12 KPI falsification 反复 治根闭环 | 5-Level evidence chain 全覆盖 PASS 路径 |
| AC5 | BE-5 (Performer-EPIC-036/037 假 PASS 第 9/10 次) 治根 — 0 commit + 0 文件 必被拦截 | L1 git-anchor 验证 + 文件存在性 |
| AC6 | Rule 9 KPI X/Y 精确格式 — 6/6 PASS = 100.0% | 测试报告输出精确数字 |

---

## 2. 设计 (跟 Rule 8 + Rule 9 + Rule 30 + Rule 31 + BE-5/BE-9 联合)

### 2.1 核心语义 — 5-Level 证据链

```
+---------------------------------------------------+
| L1: git-anchor (commit SHA 真变)                    |
|     - git rev-parse HEAD 真实存在                  |
|     - 不允许 cached SHA / fake SHA                 |
+---------------------------------------------------+
| L2: test stdout (raw 实际测试输出)                  |
|     - 必须含 "PASS" + "X/Y PASS" pattern           |
|     - 必须含 testsuite name + count                |
|     - Rule 9 精确 X/Y 格式 (no estimate)           |
+---------------------------------------------------+
| L3: 5 扩展组 pass                                  |
|     3.1 security-tool-bypass:                       |
|         - check-scope-creep.sh PASS                |
|         - check-kpi-precision.sh PASS              |
|     3.2 process-engineering:                       |
|         - check-fact-forcing-preflight.sh PASS    |
|         - l3-l4-consistency.sh PASS                |
|     3.3 auditor:                                   |
|         - auditor-checkpoint.sh PASS              |
|         - subagent-pass-gate.sh PASS              |
|     3.4 compliance:                                |
|         - check-test-case-isolation.sh PASS       |
|     3.5 decision-gate:                             |
|         - review-checkpoint.sh PASS               |
|         - rule-19-checkpoint.sh PASS              |
|     总计 9 工具, 5/5 扩展组全 PASS                 |
+---------------------------------------------------+
| L4: 独立见证签名 (audit-log-sink.sh)                |
|     - 不可篡改 audit log 写入                      |
|     - umask 077 + chmod 600 (BE-7 修复模式)        |
|     - witness signature 含 ticket_id + sha + subagent|
|     - 缺独立见证 = FAIL (跟 Rule 30/31 联合)        |
+---------------------------------------------------+
```

### 2.2 接口

```bash
# scripts/verify/kpi-evidence-chain.sh
# Usage:
#   kpi-evidence-chain.sh verify <ticket_id> <commit_sha> <test_stdout_file>
#   kpi-evidence-chain.sh check-l1 <commit_sha>
#   kpi-evidence-chain.sh check-l2 <test_stdout_file>
#   kpi-evidence-chain.sh check-l3
#   kpi-evidence-chain.sh check-l4 <ticket_id>
#
# Exit codes:
#   0 = all 4 levels PASS
#   1 = at least one level FAIL
#   2 = invalid arguments
```

### 2.3 实现策略

- **L1**: `git rev-parse <sha>^{commit}` 必须返回非空 + SHA 长度 40 + 必须是 git 已知对象. 假 SHA (如 "fake_anchor") 必返回空.
- **L2**: 读 test_stdout_file, 必须含 "PASS" (case-insensitive) + 数字/PASS pattern (e.g., "6/6 PASS"). 文件不存在或为空 = FAIL.
- **L3**: 跑 9 个 anti-fab 工具, 收集每个 group 的 PASS 状态. 任一 group 有 FAIL 工具 = 该 group FAIL. 5/5 group 必须全 PASS.
- **L4**: 调用 `audit-log-sink.sh write` 写一条独立见证记录, 验证写入成功 + 目录权限 700 + 文件权限 600. 缺独立见证 = FAIL.

### 2.4 跟 EPIC-053-A 联动

`l3-l4-consistency.sh` 已经验证 L3 集成测试 vs L4 verify 脚本 一致性. 本 ticket 把这个一致性扩展到 **4 维度** (git-anchor + test stdout + 5 扩展组 + 独立见证), 形成完整的证据链. 跟 `check-fact-forcing-preflight.sh` 6 检查 + `l3-l4-consistency` truth table 联合, 治 BE-9 自检漏洞.

### 2.5 跟 BE-5 联合

BE-5 (Performer-EPIC-036/037 假 PASS 第 9/10 次) 特征: 0 commit + 0 文件 + 报 PASS. 治根:
- L1 git-anchor 强制要求真 SHA, 假/空 SHA 必被拦截.
- L3 check-scope-creep.sh 检测 changed files > 0, 否则 PREFLIGHT FAIL.
- L4 独立见证要求 umask 077 + chmod 600, 假见证无 audit 痕迹可查.

### 2.6 跟 output-verifier.ts 联动

`node/src/core/output-verifier.ts` 当前用 5-Level Fact-Forcing (L1 git / L2 substance / L3 wiring / L4 data flow), 但**没有强制 Performer 报 PASS 时必须含 5-Level 证据**. 本 ticket 新增 `verifyPassEvidence()` 方法, 接受 5-Level 证据结构, 缺一算 FAIL.

---

## 3. 步骤 (15 步中我的子集, Step 1-8, 11-12)

| Step | 动作 | 状态 |
|------|------|------|
| 1 | 拆 worktree (Master 已建, 我验证) | ✓ |
| 2 | 加载 ticket 描述 | ✓ |
| 3 | 加载 expert profile (backend) | ✓ |
| 4 | 深度分析 (independent-witness.sh + subagent-pass-gate.sh + output-verifier.ts + l3-l4-consistency.sh + EPIC-053-A pattern + 5 扩展组工具) | ✓ |
| 5 | 写本 plan | 写入中 |
| 6 | TDD 写测试 (6 case) | 待执行 |
| 7 | 写实现 kpi-evidence-chain.sh | 待执行 |
| 8 | 跑 6/6 PASS | 待执行 |
| 9-10 | A/B review (Conductor 责任) | 跳过 |
| 11 | 写 LESSONS-LEARNED.md | 待执行 |
| 12 | 报 PASS (outbox/pass-report-EPIC-053-B.json) | 待执行 |
| 13-15 | Master 强验证 / merge (Master/Conductor 责任) | 跳过 |

---

## 4. 文件清单 (跟 file_scope 1:1)

**创建**:
- `scripts/verify/kpi-evidence-chain.sh` — 5-Level 证据链核心实现
- `tests/integration/kpi-evidence-chain-test.sh` — TDD 6 case
- `jira/tickets/EPIC-053-B/IMPLEMENTATION-PLAN.md` — 本文件
- `jira/tickets/EPIC-053-B/LESSONS-LEARNED.md` — 教训沉淀

**修改** (跟 file_scope includes):
- `scripts/audit/independent-witness.sh` — 集成 5-Level 证据链接口 (Rule 30/31 联合)
- `node/src/core/output-verifier.ts` — 新增 `verifyPassEvidence()` 方法, 强制 5-Level 证据

**不动** (边界):
- docs/, confluence/, scripts/conductor/, scripts/hooks/, node/ 其他, rust/, web/, tests/integration/ 其他 (除了新建的 kpi-evidence-chain-test.sh)

---

## 5. 测试设计 (AC2 6 case)

| Case | 场景 | 期望 |
|------|------|------|
| 1 | 5-Level 完整 + 全部 PASS | OK (exit 0) |
| 2 | 缺 1 Level (e.g., 无 L4 见证) | FAIL (exit 1) |
| 3 | 假 git-anchor (e.g., "fake_sha_123") | FAIL (L1 FAIL) |
| 4 | 假 test stdout (e.g., "all good" 无 PASS 标记) | FAIL (L2 FAIL) |
| 5 | 5 扩展组不全 (任一 group FAIL) | FAIL (L3 FAIL) |
| 6 | 缺独立见证签名 (无 audit log) | FAIL (L4 FAIL) |

**子检查**: AC6 — 6/6 PASS = 100.0% (精确 X/Y, no estimate).

**测试隔离**: 使用 temp dir, 每个 case 独立 setup/teardown. 不污染 .kallax/audit/sink 实际数据.

---

## 6. 风险 + 反模式 (跟 Rule 18 联合)

| 风险 | 缓解 |
|------|------|
| 5-Level 证据链定义不清晰 | 显式 truth table (4 维度都要, 缺 1 算 FAIL) |
| 5 扩展组工具未实现 | 跑现有 9 个 anti-fab 工具, 缺失/FAIL 也算 group FAIL |
| boundary 越界 | 用 `check-scope-creep.sh EPIC-053-B` 验证 |
| KPI falsification 反复 | commit message 用 X/Y 精确格式 (6/6 = 100.0%) |
| 自审 | A/B review 跳过 (本 ticket 范围内不在 Performer 责任) |
| 跑测试不报 PASS | pass-report 含 raw test_output (6/6 PASS) |
| 简化 5-Level 证据链 | 严格 5-Level, 缺 1 算 FAIL, 不允许降级 |
| 复制 EPIC-053-A 模式但不真实现 | 5-Level 各自独立验证逻辑, 不复用 EPIC-053-A 实现 |